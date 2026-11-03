"""Execute the actual x64 guard for missing/valid nodes and an expired bridge."""

import ctypes
import struct
import unittest

from patch_flutter_accessibility import branch, guard_code, patch_engine


class AccessibilityGuardTests(unittest.TestCase):
    def test_refuses_unknown_engine(self):
        with self.assertRaisesRegex(ValueError, "Unsupported engine"):
            patch_engine(b"unrelated or updated DLL")

    def test_native_guard(self):
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.VirtualAlloc.restype = ctypes.c_void_p
        kernel.VirtualAlloc.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong, ctypes.c_ulong]
        kernel.VirtualProtect.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong)]
        kernel.VirtualFree.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong]
        base = kernel.VirtualAlloc(None, 4096, 0x3000, 0x04)
        self.assertTrue(base, ctypes.get_last_error())
        try:
            # Windows x64 arguments RCX=node, RDX=bridge. Preserve nonvolatile RDI.
            entry = b"\x57\x48\x89\xc8\x48\x89\xd7" + branch(b"\xe9", base + 7, base + 64)
            ctypes.memmove(base, entry, len(entry))
            guard = guard_code(base + 64, base + 128, base + 144)
            ctypes.memmove(base + 64, guard, len(guard))
            # Success returns the id loaded from node+0x48; null cleanup returns RDI.
            ctypes.memmove(base + 128, b"\x89\xd0\x5f\xc3", 4)
            ctypes.memmove(base + 144, b"\x48\x89\xf8\x5f\xc3", 5)
            old = ctypes.c_ulong()
            self.assertTrue(kernel.VirtualProtect(base, 4096, 0x20, ctypes.byref(old)))
            function = ctypes.WINFUNCTYPE(ctypes.c_uint64, ctypes.c_void_p, ctypes.c_void_p)(base)
            node = ctypes.create_string_buffer(80)
            bridge = ctypes.c_uint64(0x1234)
            for child_id in (1, 42, 0x7FFFFFFF):
                struct.pack_into("<I", node, 0x48, child_id)
                self.assertEqual(function(ctypes.addressof(node), ctypes.addressof(bridge)), child_id)
            self.assertEqual(function(None, ctypes.addressof(bridge)), 0)
            self.assertEqual(function(ctypes.addressof(node), None), 0)
            self.assertEqual(function(None, None), 0)
            # A missing bridge must not dereference even a non-null invalid child.
            self.assertEqual(function(1, None), 0)
        finally:
            self.assertTrue(kernel.VirtualFree(base, 0, 0x8000))


if __name__ == "__main__":
    unittest.main()
