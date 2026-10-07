# SubnetDesk Windows helper status

2026-10-07. User-authorized execution; upstream v1.3.0 commit
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

## Verification

- Standalone tests of the actual Rust launch-policy module: Windows Flutter 1/1,
  Windows legacy/headless 1/1 pass. These are not a full Cargo build.
- Flutter panel widget tests 5/5 and existing CM API test 1/1 pass after complete bridge generation.
  Includes actual keyboard input after reopening. Modified Dart files analyze with exit 0,
  only pre-existing informational lints/deprecations; new widget/test analysis clean.
- Complete Flutter test suite: 53/53 pass. Full Flutter analysis has no errors and reports 315
  existing style/deprecation/unused warnings/information (non-fatal warning/info mode).
- LAN-only source gate passes; diff whitespace check passes.
- Full native dependencies, generated Rust/Dart bridge and Windows executable build
  are in progress. FRB code generation completed successfully; native vcpkg and Flutter Windows
  builds are still running. First Cargo attempt confirmed missing VCPKG_ROOT; it must be retried
  after native libraries are installed. No executable completion or device acceptance claimed.

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
Build outputs belong in `D:\LAN-Messenger\outputs\SubnetDesk-helper-cm`.
Do not treat this helper as integrated into LAN Messenger or as an Android change.
