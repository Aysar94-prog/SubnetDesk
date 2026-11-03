"""Apply the ChildAtIndex null guard to the pinned Flutter 3.44.1 x64 engine.

The SDK engine build dependencies are not included in this project's toolchain.
Keep the source equivalent in flutter-accessibility.patch; until an engine with
that fix is built upstream, patch only the exact, symbol-verified release DLL.
No installed DLL or SDK cache is modified. Pass a staged bundle's engine DLL.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct


ENGINE_SHA256 = "a147927018fcc1a843fb3938ead58838d2e185ce7d840bc4191a7a1b90c21015"
FAULT_RVA = 0x3E735
CONTINUE_RVA = 0x3E73B
CLEANUP_RVA = 0x3E748
ORIGINAL = bytes.fromhex("8b5048488b07")


def branch(opcode, address, destination):
    return opcode + struct.pack("<i", destination - address - len(opcode) - 4)


def guard_code(address, continuation, cleanup):
    """RAX=AXNode*, RDI=locked bridge; preserve the original shared_ptr cleanup."""
    null_path = address + 29
    return (
        b"\x48\x85\xc0"  # test rax, rax
        + branch(b"\x0f\x84", address + 3, null_path)
        + b"\x48\x85\xff"  # test rdi, rdi
        + branch(b"\x0f\x84", address + 12, null_path)
        + ORIGINAL  # child->id(), followed by loading bridge's vtable
        + branch(b"\xe9", address + 24, continuation)
        + b"\x31\xff"  # missing node/bridge: return nullptr
        + branch(b"\xe9", address + 31, cleanup)
    )


def align(value, alignment):
    return (value + alignment - 1) // alignment * alignment


def patch_engine(data):
    if hashlib.sha256(data).hexdigest() != ENGINE_SHA256:
        raise ValueError("Unsupported engine SHA256; refusing to patch another engine")
    result = bytearray(data)
    pe = struct.unpack_from("<I", result, 0x3C)[0]
    machine, count = struct.unpack_from("<HH", result, pe + 4)
    optional_size = struct.unpack_from("<H", result, pe + 20)[0]
    optional = pe + 24
    if result[pe:pe + 4] != b"PE\0\0" or machine != 0x8664:
        raise ValueError("Expected a Windows x64 engine")
    if struct.unpack_from("<H", result, optional)[0] != 0x20B:
        raise ValueError("Expected PE32+")
    section_alignment, file_alignment = struct.unpack_from("<II", result, optional + 32)
    header_size = struct.unpack_from("<I", result, optional + 60)[0]
    certificate = struct.unpack_from("<II", result, optional + 112 + 4 * 8)
    if certificate != (0, 0):
        raise ValueError("Refusing to invalidate an Authenticode signature")
    table = optional + optional_size
    sections = []
    for index in range(count):
        entry = table + index * 40
        size, rva, raw_size, raw = struct.unpack_from("<IIII", result, entry + 8)
        sections.append((rva, size, raw, raw_size))
    new_header = table + count * 40
    if new_header + 40 > min(header_size, min(s[2] for s in sections)):
        raise ValueError("No space for the guard section header")
    if any(result[new_header:new_header + 40]):
        raise ValueError("New section header would overwrite data")
    executable = next(s for s in sections if s[0] <= FAULT_RVA < s[0] + s[1])
    fault_offset = executable[2] + FAULT_RVA - executable[0]
    if result[fault_offset:fault_offset + len(ORIGINAL)] != ORIGINAL:
        raise ValueError("ChildAtIndex instruction signature mismatch")
    guard_rva = align(max(s[0] + max(s[1], s[3]) for s in sections), section_alignment)
    raw_offset = align(len(result), file_alignment)
    guard = guard_code(guard_rva, CONTINUE_RVA, CLEANUP_RVA)
    # The branch runs inside ChildAtIndex's existing stack frame. Give Windows
    # an unwind record for it, so stack walking and exception dispatch continue
    # to restore RSP/RDI/RSI correctly while the thread is in the guard.
    unwind_offset = align(len(guard), 4)
    unwind = bytes.fromhex("01000300 0042 0070 0060 0000")
    table_offset = align(unwind_offset + len(unwind), 4)
    exception_rva, exception_size = struct.unpack_from("<II", result, optional + 112 + 3 * 8)
    exception_section = next(s for s in sections if s[0] <= exception_rva < s[0] + s[1])
    exception_offset = exception_section[2] + exception_rva - exception_section[0]
    if exception_size % 12:
        raise ValueError("Unexpected exception directory size")
    exceptions = result[exception_offset:exception_offset + exception_size]
    if any(struct.unpack_from("<I", exceptions, offset)[0] >= guard_rva
           for offset in range(0, exception_size, 12)):
        raise ValueError("Exception directory would become unsorted")
    payload = bytearray(table_offset)
    payload[:len(guard)] = guard
    payload[unwind_offset:unwind_offset + len(unwind)] = unwind
    payload.extend(exceptions)
    payload.extend(struct.pack("<III", guard_rva, guard_rva + len(guard), guard_rva + unwind_offset))
    raw_size = align(len(payload), file_alignment)
    result.extend(bytes(raw_offset + raw_size - len(result)))
    result[raw_offset:raw_offset + len(payload)] = payload
    # RX code only, no writable/executable memory in the packaged DLL.
    struct.pack_into("<8sIIIIIIHHI", result, new_header, b".sdax\0\0\0", len(payload),
                     guard_rva, raw_size, raw_offset, 0, 0, 0, 0, 0x60000020)
    struct.pack_into("<H", result, pe + 6, count + 1)
    code_size = struct.unpack_from("<I", result, optional + 4)[0]
    struct.pack_into("<I", result, optional + 4, code_size + raw_size)
    struct.pack_into("<I", result, optional + 56, align(guard_rva + len(payload), section_alignment))
    struct.pack_into("<II", result, optional + 112 + 3 * 8, guard_rva + table_offset, exception_size + 12)
    result[fault_offset:fault_offset + 6] = branch(b"\xe9", FAULT_RVA, guard_rva) + b"\x90"
    # PE checksum is optional for user DLLs; regenerate it after all changes.
    struct.pack_into("<I", result, optional + 64, 0)
    checksum = 0
    for offset in range(0, len(result), 2):
        checksum += int.from_bytes(result[offset:offset + 2], "little")
        checksum = (checksum & 0xFFFF) + (checksum >> 16)
    checksum = (checksum & 0xFFFF) + (checksum >> 16)
    struct.pack_into("<I", result, optional + 64, checksum + len(result))
    return bytes(result), {"engineSha256": ENGINE_SHA256, "guardRva": hex(guard_rva),
                           "faultRva": hex(FAULT_RVA), "guardSize": len(guard),
                           "patchedSha256": hashlib.sha256(result).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("engine", type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    patched, metadata = patch_engine(args.engine.read_bytes())
    # Atomic replacement in the candidate bundle; keep SDK and current releases intact.
    temporary = args.engine.with_suffix(".sdax.tmp")
    with temporary.open("xb") as stream:
        stream.write(patched)
    temporary.replace(args.engine)
    args.manifest.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata))


if __name__ == "__main__":
    main()
