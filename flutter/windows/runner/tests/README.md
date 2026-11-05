# Windows runner argument regression

The test includes the production `command_line.h` used by `main.cpp`. It requires only a
C++17 compiler, not Flutter plugins or a running remote session. Seventeen cases cover intact
CM/install/connect/headless flags, trailing whitespace, empty/all-whitespace, addresses and UTF-8.
The original erase-at-last-character implementation fails 17/17, including exceptions for empty
arguments. The corrected implementation passes 17/17.

Standalone CMake/CTest workflow (choose an output directory outside source):

```powershell
cmake -S flutter/windows/runner/tests -B D:/LAN-Messenger/outputs/SubnetDesk-helper-cm/checks/native-cmake -G "Visual Studio 17 2022" -A x64
cmake --build D:/LAN-Messenger/outputs/SubnetDesk-helper-cm/checks/native-cmake --config Release
ctest --test-dir D:/LAN-Messenger/outputs/SubnetDesk-helper-cm/checks/native-cmake -C Release --output-on-failure
```

Tests pass only when the actual helper preserves launch arguments. This does not prove IPC,
Flutter CM initialization or panel visibility; run the rebuilt app with `--cm` alongside its
main window, then test an actual incoming session. Do not reuse an old/headless CM or backend.

## Native accessibility fallback

`native_accessibility_fallback` exercises the actual production subclass with
a real message-only HWND. It verifies 4000 MSAA/UIA provider queries use Windows
default handling, other messages still reach the original procedure, and callback
removal/destruction work. This fallback intentionally limits Flutter widget-level
screen-reader/UIA support; normal window proxies, input and rendering remain.
