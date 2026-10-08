# SubnetDesk Windows helper status

## Current authorized repair/build/runtime: 2026-10-08 09:48 Asia/Jerusalem

Windows native runner trims only trailing whitespace via production command_line.h and safely
handles empty/all-whitespace. Actual helper tests reproduce original0/17 and now pass17/17;
standalone CMake/CTest1/1, launch policy2/2, full Flutter53/53. Full-feature Rust release and
Flutter Windows Release pass; 46 pre-existing Rust warnings retained. Shared package metadata
is now Rust1.3.1/Flutter1.3.1+76 for this LOCAL helper candidate, not official upstream1.3.1.
No Android application implementation/APK or LAN Messenger code/protocol/signing changes.

Complete staged folder: outputs/SubnetDesk-helper-cm/Windows-x64-v1.3.1-cm-dock.
Windows File/ProductVersion1.3.1+76; isolated-data CLI1.3.1/exit0; bundled Rust DLL matches build.
Approved runtime switch at09:47:38 interrupted old candidate. New main PID4052 owns TCP21118.
Original installed service Stopped/Auto, files/path untouched. Manual new --cm PID8696 survives
5s and logs --cm started/FFI cm initialization, then disappears without clients, consistent with
existing6s idle close. This is NOT visible dock/session acceptance. Manual CM no longer present;
user asked to reconnect Android for automatic CM launch and actual panel/chat/fold acceptance.
Logs: checks/runner-fix-build.log and runtime-1.3.1-{main,cm}.{stdout,stderr}.txt.
Old1.3.0 bundle/archives preserved; new binary/source packaging in progress.
Older observations below are historical; earlier user dock acceptance FAILED.

## Superseding diagnosis: 2026-10-08, live dock acceptance failed

Phone .51 has an Established session to the candidate on .12:21118/PID1896, original service
Stopped. User still sees no dock. Candidate main log reports Failed to connect to connection
manager; no CM process persists. Direct --cm diagnostic exits1, main session remains connected.
Native runner main.cpp:50 erases from the last non-whitespace index rather than after it,
turning --cm into --c and defeating the --cm multiple-instance allowlist. Original upstream
has this bug too; first repair/test suite missed native argument parsing. New Windows-only
repair/native-regression/version plan in LAN source PLAN-SUBNETDESK-WINDOWS-RUNNER.md.
Application source/version/build unchanged in this diagnosis; implementation awaits start.

## Current runtime checkpoint: 2026-10-08 09:32 Asia/Jerusalem

User explicitly approved a temporary old-backend stop on this computer, 192.168.1.12.
Original installed service is now Stopped; Automatic startup and installed path are unchanged.
Old server, headless CM and tray are gone. Candidate restarted as PID1896 and owns TCP21118;
native main-window handle exists. User asked to reconnect phone for incoming-session acceptance.
No candidate --cm window/session, fold/unfold, chat or audible Voice acceptance yet.
Earlier user attempts had no dock while the old service/backend still owned the receiver.
No installed files/settings were deleted or replaced; version remains 1.3.0+75. Windows reboot
may restart the original service. Rollback: stop candidate, then Start-Service SubnetDesk with
administrative rights. Stop helper transcript is in outputs/SubnetDesk-helper-cm/checks.
Older running-service observations below describe the pre-handoff state.

2026-10-07 source work; 2026-10-08 build checkpoint. User-authorized execution; upstream v1.3.0 commit
`a412726163265a0e18deb0b8244ac1e87fb6ffd5`, hbb_common
`ce351cc6147420147e4950ce25e6affbeecd191e`.

## Implemented source (Windows only)

- Interactive Flutter incoming sessions launch `--cm`, not `--cm-no-ui`.
  Existing IPC reuse, prelogin wait and run-as-user handling remain intact.
- CM has a taskbar entry and an always-on-top bottom-right 360x600 session dock.
  Folding leaves a 360x44 header. New sessions and incoming Voice expand it.
- The dock reuses the existing chat, permissions, Voice and Disconnect handlers.
  Multiple sessions can be selected; folded chat arrivals increase the unread badge.
  Model-owned drafts survive folding and switching between chat and controls.
- Windows ignores the old hidden-CM option for this always-visible helper dock.
  The three-second auto-minimize and opacity-restoration minimize are removed on Windows.
  Periodic state polling does not restore/focus a manually minimized dock.
- Existing remote-input protection is preserved. Chat remains keyboard-focusable;
  permission controls retain the existing key-event exclusion.

No Android implementation/build, wire-format change or LAN Messenger application change.
No installed executable has been replaced; no network/session acceptance claimed.
The original SubnetDesk service is Running/Auto at
`C:\Program Files\SubnetDesk\SubnetDesk.exe --service`; it was inspected read-only and not stopped.
That old service can still launch the old/headless CM. Opening this candidate alongside it is
not proof that a session uses the patched backend. Service/backend handoff needs the user's
direction and must account for any active sessions.

## Verification

- Standalone tests of the actual Rust launch-policy module: Windows Flutter 1/1,
  Windows legacy/headless 1/1 pass. These are not a full Cargo build.
- Flutter panel widget tests 5/5 and existing CM API test 1/1 pass after complete bridge generation.
  Includes actual keyboard input after reopening. Modified Dart files analyze with exit 0,
  only pre-existing informational lints/deprecations; new widget/test analysis clean.
- Complete Flutter test suite: 53/53 pass. Full Flutter analysis has no errors and reports 315
  existing style/deprecation/unused warnings/information (non-fatal warning/info mode).
- LAN-only source gate passes; diff whitespace check passes.
- Complete native manifest installation: all 16 packages pass. FRB generation completed.
- Full Rust library (flutter,software-update,hwcodec,vram), Flutter Windows Release build,
  virtual-display DLL and pinned WindowInjection DLL all build with exit 0. Earlier dependency
  failures were resolved without unrelated application/dependency source refactors.
- Candidate CLI/native-loader smoke in isolated APPDATA/LOCALAPPDATA: exit 0, version 1.3.0.
  This is not graphical CM, remote-session, audible Voice or physical device acceptance.
- Candidate: `D:\LAN-Messenger\outputs\SubnetDesk-helper-cm\Windows-x64-v1.3.0-cm-dock`.
  Original auxiliary driver resources/notices included; printer archives match published
  checksums. No driver installation or service change performed.

## Required physical acceptance

1. Start the candidate with no old/headless CM holding its IPC socket.
2. Android-originated session: dock immediately visible and still visible after >3 seconds.
3. Bottom-right positioning at actual DPI/work area; fold/unfold and taskbar recovery.
4. Bidirectional chat and draft preservation; unread badge while folded.
5. Incoming Voice while folded, accept/end, actual audible audio; Disconnect/reconnect.
6. Multiple-session selection and unchanged permission/remote-input protection.
7. Installed-service/run-as-user behavior, prelogin wait, manual minimize and service restart.

## Local build environment

Tools: `D:\LAN-Messenger\reference\SubnetDesk-v1.3.0\tools`.
Temporary `S:` mapping points to that exact directory to avoid Windows path-length failures.
Rust 1.82.0, Flutter 3.44.1/Dart 3.12.1, FRB codegen 1.80.1, LLVM 15.0.6.
MSVC 2022 BuildTools; vcpkg baseline `120deac3062162151622ca4860575a33844ba10b`.
Scoped CARGO_HOME/RUSTUP_HOME/PUB_CACHE; no global PATH/toolchain changes.
Flutter's generated plugin links use local directory junctions because this user token cannot
create symlinks. Developer Mode/security settings were not changed. Build with --no-pub to
preserve these generated junctions; a future pub get may recreate the link directory.
`tools/vcpkg/installed` is a local junction to `tools/native-installed`: some upstream Rust
dependencies ignore VCPKG_INSTALLED_ROOT and require VCPKG_ROOT/installed. No upstream dependency
source was patched to compensate.
Build outputs belong in `D:\LAN-Messenger\outputs\SubnetDesk-helper-cm`.
Do not treat this helper as integrated into LAN Messenger or as an Android change.
