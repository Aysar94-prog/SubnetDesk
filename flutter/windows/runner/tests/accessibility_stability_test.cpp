#include "../accessibility_stability.h"

#include <iostream>

namespace {
int flutter_queries = 0;
LRESULT CALLBACK TestWindowProc(HWND window, UINT message,
                                WPARAM wparam, LPARAM lparam) {
  if (message == WM_GETOBJECT) {
    ++flutter_queries;
    return 1234;
  }
  if (message == WM_APP + 1) return 5678;
  return DefWindowProcW(window, message, wparam, lparam);
}
}  // namespace

int main() {
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = TestWindowProc;
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.lpszClassName = L"SubnetDeskAccessibilityRegression";
  if (!RegisterClassW(&window_class)) return 1;
  const HWND window = CreateWindowW(window_class.lpszClassName, L"test", 0,
      0, 0, 0, 0, HWND_MESSAGE, nullptr, window_class.hInstance, nullptr);
  if (!window) return 2;
  if (!subnetdesk::UseStableAccessibility(window)) return 3;
  // Include both sign-extended and zero-extended object identifiers, as sent
  // by real Windows accessibility clients on x64.
  for (int i = 0; i < 1000; ++i) {
    for (LONG object : {OBJID_CLIENT, static_cast<LONG>(UiaRootObjectId)}) {
      SendMessageW(window, WM_GETOBJECT, 0, static_cast<LPARAM>(object));
      SendMessageW(window, WM_GETOBJECT, 0,
                   static_cast<LPARAM>(static_cast<DWORD>(object)));
    }
  }
  if (flutter_queries != 0) return 4;
  if (SendMessageW(window, WM_APP + 1, 0, 0) != 5678) return 5;
  if (SendMessageW(window, WM_GETOBJECT, 0, OBJID_CARET) != 1234) return 6;
  if (flutter_queries != 1) return 7;
  if (!RemoveWindowSubclass(window, subnetdesk::StableAccessibilityProc,
                            0x53444158)) return 8;
  if (SendMessageW(window, WM_GETOBJECT, 0, OBJID_CLIENT) != 1234) return 9;
  if (!subnetdesk::UseStableAccessibility(window)) return 10;
  if (!DestroyWindow(window)) return 11;
  if (!UnregisterClassW(window_class.lpszClassName, window_class.hInstance)) return 12;
  std::cout << "PASS: 4000 native accessibility queries use Windows fallback; "
               "other messages and callback lifetime preserved\n";
  return 0;
}
