#ifndef SUBNETDESK_ACCESSIBILITY_STABILITY_H_
#define SUBNETDESK_ACCESSIBILITY_STABILITY_H_

#include <windows.h>
#include <commctrl.h>
#include <UIAutomation.h>

namespace subnetdesk {

// Use Windows' generic window proxy instead of activating Flutter 3.44's
// unstable AX tree. This intentionally limits widget-level screen-reader/UIA
// access; it does not change input, rendering, permissions or system settings.
inline bool IsFlutterAccessibilityRequest(UINT message, LPARAM parameter) {
  const DWORD object = static_cast<DWORD>(static_cast<DWORD_PTR>(parameter));
  return message == WM_GETOBJECT &&
         (object == static_cast<DWORD>(OBJID_CLIENT) ||
          object == static_cast<DWORD>(UiaRootObjectId));
}

inline LRESULT CALLBACK StableAccessibilityProc(HWND window, UINT message,
                                               WPARAM wparam, LPARAM lparam,
                                               UINT_PTR id, DWORD_PTR) {
  if (IsFlutterAccessibilityRequest(message, lparam)) {
    return DefWindowProcW(window, message, wparam, lparam);
  }
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, StableAccessibilityProc, id);
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

inline bool UseStableAccessibility(HWND window) {
  return window && SetWindowSubclass(window, StableAccessibilityProc,
                                    0x53444158, 0) != FALSE;
}

}  // namespace subnetdesk

#endif  // SUBNETDESK_ACCESSIBILITY_STABILITY_H_
