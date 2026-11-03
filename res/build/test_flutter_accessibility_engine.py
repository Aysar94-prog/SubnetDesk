"""Integration regression: run ChildAtIndex inside the actual patched engine.

Run in its own process: a regression in native code must fail the test process.
The zero-initialized native fixture represents a leaf AXNode and an expired
weak bridge. Chromium's release iterator returns no children for this fixture.
"""

import argparse
import ctypes
import hashlib
from pathlib import Path

from patch_flutter_accessibility import patch_engine


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("original", type=Path)
    parser.add_argument("test_directory", type=Path)
    args = parser.parse_args()
    args.test_directory.mkdir(parents=True, exist_ok=True)
    output = args.test_directory / "flutter_windows.dll"
    patched, metadata = patch_engine(args.original.read_bytes())
    with output.open("xb") as stream:
        stream.write(patched)
    assert hashlib.sha256(output.read_bytes()).hexdigest() == metadata["patchedSha256"]
    engine = ctypes.WinDLL(str(output.resolve()))
    lookup = ctypes.WinDLL("ntdll").RtlLookupFunctionEntry
    lookup.restype = ctypes.c_void_p
    lookup.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64), ctypes.c_void_p]
    image_base = ctypes.c_uint64()
    guard_address = engine._handle + int(metadata["guardRva"], 16)
    runtime_function = lookup(guard_address, ctypes.byref(image_base), None)
    assert runtime_function and image_base.value == engine._handle
    child_at_index = ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int)(
        engine._handle + 0x3E6F6
    )
    leaf = ctypes.create_string_buffer(2048)
    delegate = ctypes.create_string_buffer(64)
    ctypes.c_void_p.from_buffer(delegate, 8).value = ctypes.addressof(leaf)
    for _ in range(1000):
        for index in (-1, 0, 1, 1000000):
            assert child_at_index(ctypes.addressof(delegate), index) is None
    # Check the real engine's success path, including balanced shared_ptr refs.
    # Layouts and call-site offsets are pinned to ENGINE_SHA256 by patch_engine.
    child = ctypes.create_string_buffer(2048)
    ctypes.c_int.from_buffer(child, 0x48).value = 42
    children = (ctypes.c_void_p * 1)(ctypes.addressof(child))
    ctypes.c_void_p.from_buffer(leaf, 0x28).value = ctypes.addressof(children)
    ctypes.c_void_p.from_buffer(leaf, 0x30).value = ctypes.addressof(children) + 8
    ctypes.c_void_p.from_buffer(leaf, 0x38).value = ctypes.addressof(children) + 8
    seen = []
    @ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int)
    def accessible_from_id(bridge, child_id):
        seen.append(child_id)
        return 0x12345678
    vtable = (ctypes.c_void_p * 4)(0, 0, 0, ctypes.cast(accessible_from_id, ctypes.c_void_p).value)
    bridge = ctypes.c_void_p(ctypes.addressof(vtable))
    control = ctypes.create_string_buffer(32)
    ctypes.c_int.from_buffer(control, 8).value = 1
    ctypes.c_int.from_buffer(control, 12).value = 1
    ctypes.c_void_p.from_buffer(delegate, 16).value = ctypes.addressof(bridge)
    ctypes.c_void_p.from_buffer(delegate, 24).value = ctypes.addressof(control)
    for _ in range(1000):
        assert child_at_index(ctypes.addressof(delegate), 0) == 0x12345678
        assert ctypes.c_int.from_buffer(control, 8).value == 1
    assert seen == [42] * 1000
    ctypes.c_void_p.from_buffer(leaf, 0x30).value = ctypes.addressof(children)
    assert child_at_index(ctypes.addressof(delegate), 0) is None
    assert ctypes.c_int.from_buffer(control, 8).value == 1
    ctypes.c_int.from_buffer(control, 8).value = 0
    assert child_at_index(ctypes.addressof(delegate), 0) is None
    print("PASS: patched engine: 4000 missing-child queries and 1000 valid-child queries; bridge refs balanced")


if __name__ == "__main__":
    main()
