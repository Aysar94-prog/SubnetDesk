# SubnetDesk Windows helper status

## Camera removal checkpoint:2026-10-08

Final Windows1.3.3+78 native no-updater release and Flutter release builds PASS; full Flutter
65/65 rerun PASS. Staged Windows-x64-v1.3.3-private native DLL matches rebuilt output.
CLI --version returns1.3.3/exit0; --update exits0 without installing (blocked branch returns
normally, so exit0 alone is not updater acceptance). Source/API feature-enabled denial tests
above are the operation-denial evidence. User approved runtime switch after build completion.
Old1.3.1 closed normally using Windows UI; no active TCP session at handoff. Initial new
hidden-start process was restarted before connections; visible new PID25332 owns listener21118
and UI showsv1.3.3. Windows Firewall permission dialog requires user handling; automation
stopped at this security prompt. Original installed service remains Stopped/Auto/path unchanged.
Paired screen/voice/camera-denial/ring/buzzer acceptance and Android APK remain pending.
Android main native dependencies completed successfully; Windows-host libsodium cross-build
is a separate prerequisite in progress. No source claims of working Android APK yet.

User explicitly approved removal of SubnetDesk View camera on Windows and Android only.
Mobile/peer/desktop toolbar entry points removed; shared connect and native session/client
routes reject camera. Encrypted incoming login/scope guards deny old camera requests and
advertised support_view_camera is false. Remote screen/control and voice code retained;
LAN Messenger video is not modified. Source1.3.3/Flutter1.3.3+78 identifies this candidate.
Windows frontend release and Flutter65/65 pass; native camera3/3, updater4/4 (feature enabled),
chat attention5/5, encrypted loopback/protocol6/6 and visible CM launch1/1 pass. Candidate/source
archives pending. Physical old-peer camera denial,
screen/voice regression and new buzzer/ring acceptance not completed; old1.3.1 not switched.
Android native dependency build is in progress in scoped user SDK/NDK/output directories.
Narrow Android-on-Windows AOM assembler and FFmpeg argument delimiter fixes preserve the
Windows build path. Candidate Android Gradle pins NDK28.2 to match native builds; original
build defaults unchanged. No new APK or original-package modification. Access modes/Keystore and
chat-memory cleanup remain approved but not implemented. Previous checkpoint is historical.

## Private helper approved work checkpoint:2026-10-08

Supersedes older waiting-for-start and microphone-not-granted statements below. User approved
microphone grant, side-by-side Android candidate, all access-mode/ring/buzzer implementation,
and permanent updater shutdown explicitly. Phone mic granted/AppOps foreground; user reports
voice works and recorder startup success logged10:29:29. Windows ring was missing in source.

Source now includes typed authenticated/rate-limited Android->Windows ChatAttention protocol,
visible non-activating bottom-right dock attention, independent buzzer mute, and a bounded
incoming voice alert (every3s/max30s) with separate mute/transition cleanup. Full Flutter65/65
pass; buzzer pure Rust5/5 pass and first no-updater native release build pass. Later native
installer guards/final frontend build, archives and physical acceptance remain pending.
Immutable private policy denies every updater API, scheduler/preference enablement and Windows
legacy update CLI/installers; About controls/events removed. Private builds omit updater feature.
Tests deliberately enabling that feature are running. Source version1.3.2/Flutter1.3.2+77;
running1.3.1 is unchanged and has not inherited these changes.

Three access modes and Android encrypted remembered credentials are approved but NOT implemented.
Scoped Android SDK36/NDKr28c installed outside original app/source; native/APK candidate pending.
Original Android package/data and LAN Messenger signing key untouched. No stored chat/buzz
history added, but existing in-memory chat across reconnect still needs explicit cleanup work.
Original Windows service remains Stopped/Auto/unmodified; no installed-release replacement.
No claim of paired buzzer/ring, updater runtime acceptance, secure new login methods or integration.

## Voice diagnosis and new buzzer plan: 2026-10-08

Read-only connected-phone inspection confirms installed Android1.3.0/code2075 RECORD_AUDIO
granted=false/AppOps ignore, with matching10:01:23 capture-permission and onVoiceCallStarted
failure logs. Microphone permission was not changed; no new call or audible retest performed.
This recorded failure is on Android capture, not evidence that Windows audio has passed.
User-supplied login secrets are not stored in source/status/log artifacts.

New chat-buzzer plan is in D:/LAN-Messenger/source/PLAN-SUBNETDESK-CHAT-BUZZER.md: first-stage
Android sender -> Windows receiver, typed optional session event, short sound/visible dock
attention, receiver mute/rate limits and mixed-version tests. Explicit start still required;
no app code/build/protocol or package identity changed. No persistent chat/buzz history added.
Android password saving remains separate and plan-only. Current Windows1.3.1 artifacts
remain unchanged; initial dock visibility acceptance does not imply audible Voice acceptance.

## Latest physical acceptance: 2026-10-08

User confirmed "ok now this is good" after reconnecting phone: initial incoming dock visibility
accepted for local candidate1.3.1+76. Live Android .51 -> .12:21118 belongs to main PID4052;
automatic child CM PID12188 runs candidate --cm and has native window handle656146. This is
actual incoming-session evidence, not the earlier manually launched no-client smoke.
Fold/drafts/unread, bidirectional chat, audible Voice, DPI/multiple sessions and installed-service/
prelogin/reboot behavior still need separate physical acceptance. Old service Stopped/Auto and
installed files untouched. No binary changes/repackaging; existing archive hashes unchanged.
Android remember-password still plan-only; no LAN Messenger integration or parity change.

Packaging checkpoint: local source commit2aa0dc7 supplied in helper-v1.3.1 source ZIP with
pinned hbb_common/WindowInjection;1180 entries and private-material gate pass. Windows binary
ZIP complete; hashes in outputs/SubnetDesk-helper-cm/SHA256SUMS.txt. No push. Runtime/session
initial incoming visibility now accepted; other acceptance gates remain pending. Documentation
updates do not alter app binaries; code in the supplied source archive still matches the build.

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
Old1.3.0 bundle/archives preserved; new binary/source archives complete, see packaging checkpoint.
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
