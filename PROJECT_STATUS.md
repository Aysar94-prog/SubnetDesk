# LAN Messenger project status and platform comparison

2026-10-10 Android SubnetDesk Helper outgoing-only (plan-v002) build88 BUILT AND DEVICE-
VERIFIED: flutter analyze/test PASS, aapt badging confirms only the 4 retained permissions
and no hosting service/receiver, upgrade from build85 without clearing data PASS on a
physical Samsung SM-S908E, and Windows-to-Android control attempts failed (refused, no
prompt, no listener) immediately after upgrade, after app restart, and after a phone
reboot. Not yet covered: a dedicated fresh-install permission-prompt-timing check, a
previously-enabled-receiver-setting carryover check, and the positive-path Android-to-
Windows control session. Not committed yet, pending approval. See android/STATUS.md.

2026-10-10 Android SubnetDesk Helper outgoing-only (plan-v002) CODE COMPLETE, not built:
Android no longer hosts (no MainService/InputService/BootReceiver/floating window, no
FFI.startServer path, no Share screen/incoming chat/LAN host settings). Permissions reduced
to INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE and runtime-on-use RECORD_AUDIO; broad
storage replaced by app transfer folder + system picker. Windows code and wire unchanged.
Build/flutter test/device acceptance pending. See android/STATUS.md.

| Android outgoing-only | Windows87 | Android (build88, device-verified) | Evidence / acceptance |
|---|---|---|---|
| Phone as controlled host | Not applicable | Removed at every entry point | Source guards + parse PASS; upgrade/restart/reboot control attempts all failed as expected |
| PC control from phone | Receiver unchanged | Sender paths unchanged | No wire/native change; positive-path paired test still pending |
| Permissions | Unchanged | 4 retained, 11 stripped | aapt merged-manifest check PASS on build88 |

2026-10-09 FINAL separate SubnetDesk Windows1.3.8/build87: in-session Transfer file
and password-required retry offer all three English methods without username; pending
duplicate file tab consumes explicit selection, active jobs/tab retained and cancel
file-only. Additive optional-file ABI with pending/IO active guards, no control grant
reuse, encrypted wire unchanged. User approved Administrator MSI + Desktop shortcut.
Productioneef9c45/source snapshot4bd89d8/common29462e6; local commits/no push.
Native13 new +50 prior regressions/pure6+15/CTest3 PASS; Flutter136, full138 against
rebuilt DLL plus isolated2 smoke PASS. First smoke fixture double-FRB-instance error
corrected without app change; actual VERSION1.3.8/new missing-session ABI verified.
Analyzers clean on widgets/tests/smoke; routing60 old info/no errors/warnings.
Native6m26s/UI121.1s. MSI6A473880...473F70 readonly English/x64/ALLUSERS1/elevated/
ProgramFiles/common advertised Desktop+Start/actual EXE keypaths/old-user launch gate/
isolation/all125 extracted hashes PASS, explicit ICE ExitCode0/DiagnosticCount0;
seven inherited neutral font binder notices. EXE8FB8C1BC...7D9466C2/DLLB80444AD...A6DD8C72.
Portable5960F3E5...282AD018/source3D2A19E2...DA9A86F7/private gate1250 entries PASS.
Outputs/SubnetDesk-helper-cm contains MSI/ZIP/source/SHA256SUMS-build87.txt/release/
acceptance checklist. Old86 runtime was verified externally installed read-only;
no87 MSI run, runtime switch/uninstall/security/service/original-app change here.
Machine MSI cannot major-upgrade per-user86: human closes/uninstalls only old private
Helper (settings preserved), then installs87 and approves UAC; current installation
user's HKCU marker gates old install, not an all-profile sweep. Actual UAC/shortcut/
repair/uninstall and password/code/manual file acceptance pending. Unsigned MSI;
VC++ x64 runtime prerequisite retained. Android exact85 APK/hash46C43D1B...CDC7737 and
signer retained; reported security warning unresolved. No LAN Messenger integration.

| Current private helper compatibility | Windows87 | Android85 | Evidence / acceptance |
|---|---|---|---|
| File sender entry | Add/peer/in-session Transfer file + required-password retry: all three methods; file-only pending-channel retry | Existing password/code/manual paths retained, no APK rebuild | Existing wire contract4 PASS, native guards; real cross-device files pending |
| Receiver/manual/code | DefaultON preference/local Accept/file scope; reusable7200s code unchanged | Existing sender wire unchanged | No auto-accept, grant inheritance or lifetime change; device acceptance pending |
| Release/install | EXE1.3.8+87, machine Administrator MSI, Desktop/Start shortcuts | Retained1.3.7/versionCode2085 | Intentionally Windows-only release; no matching87 APK or new signer |

## Historical build86 checkpoint

2026-10-09 SubnetDesk Windows sender correction86 COMPLETE in code/artifacts, actual
paired/install acceptance pending. User explicitly authorized execution; plan
PLAN-SUBNETDESK-WINDOWS-SENDER.md. Productionab843af/source snapshot e3d0a63/common29462e6.
Windows Add and ordinary discovered/recent/favorite Connect now select password/saved,
six-digit temporary code or manual request. Optional payloads exclude account/password/
remember, invalid input blocks dispatch, method/endpoint switches clear fields. No native/
ABI/wire changes: exact85 DLL4FA47528...808AF958 retained; Android85 byte-identical.
13 new UI/routing guards/full post-build Flutter123 PASS; new widget/test analyzer clean,
routing26 pre-existing info/no errors. Windows frontend163.4s. MSI1.3.7/build86 hash
AFE310FF...0AE33E55, readonly English/x64/per-user/private isolation/same-version Upgrade
flag/all125 extracted payload hashes PASS. Explicit ICE zero errors; intentional ICE91
and narrowly accepted exact equal-version ICE61; initial85-only warning guard rejected
ICE61, reviewed rerun PASS. Source1240 entries/private exclusion PASS, ZIP/source/MSI/
SHA256SUMS-build86.txt/release/acceptance notes in outputs/SubnetDesk-helper-cm. Same-
public-version MSI85->86 upgrade enabled, cannot gate logical-build rollback within1.3.7.
No install/runtime/original-app/service/security changes. Windows MSI unsigned; Android85
still uses existing Debug certificate, reported Android warning unresolved/separate issue.
No LAN Messenger production/integration change; physical acceptance not inferred from tests.

| Historical build86 compatibility | Windows sender / receiver | Android sender | Evidence |
|---|---|---|---|
| Three sender methods | build86 Add + ordinary peer Connect selector; receiver85 gates retained | Existing85 password/code/manual sender unchanged | Flutter123 + routing-source guards PASS; native85 review/hash retained; actual paired pending |
| Manual approval | Missing preference ON, explicit saved ON/OFF; local Accept required | Existing request/pending wire | No auto-accept/protocol changes; real Accept/Deny/timeout pending |
| Temporary code | Existing reusable7200s/main-restart code | Existing six-digit sender | No lifetime change this fix; real reuse/restart pending |
| Release identity | New MSI HELPER_BUILD86 / EXE1.3.7+86 | Retained versionName1.3.7 / versionCode2085 | Same public release1.3.7; Android not rebuilt/re-signed, byte hash verified |

2026-10-09 FINAL SubnetDesk85 requested artifacts ready: Both release1.3.7/logical85,
APK internal2085. Source snapshot3af9c05/productionc88c34f/common29462e6, MSI f4d27e4.
50 selected native/config/encrypted-wire/hash, Flutter110 before/after Windows build,
pure policy15 and CTest3 PASS. Windows native5m26s/UI104.6s, Android native7m06s/APK565.6s.
Final unsigned per-user MSI8AE809C2...0E03CB0 passes readonly identity/isolation/all125
extracted payload hashes and explicit ICE (zero errors; intentional per-user ICE91 only).
Original-app/service/security/data not modified; no installer/APK installed this turn.
APK46C43D1B...CDC7737/signer/no-camera/16KB/exact-native/English AOT key+oldArabicabsence
PASS. Both corresponding source archives/private gates1237/1363 PASS, checksums and
release/acceptance notes in outputs/SubnetDesk-helper-cm. WindowInjection VC++ x64 runtime
prerequisite exists on target laptop; other machines/clean install not accepted. Manual
defaultON/savedOFF/ON implemented; physical paired/restart/code/saved/chat/buzz/voice and
MSI install/uninstall acceptance still open. No LAN Messenger integration/completion claim.

2026-10-09 SubnetDesk manual-default execution explicitly started; user additionally
requests matching final MSI/APK. Both release1.3.7/logicalbuild85, Android internal2085
preserves upgrade order. Sourcec88c34f/common29462e6 defaults missing Windows preference
ON, remembers checked ON/OFF, invalid/save errors fail closed with English UI. No code/
nonce/request/acceptance persistence; receiver lock/stop/service/60s gates retained.
Flutter110/pure policy15/runner CTest3 PASS; full native/Windows/Android builds executing.
Private per-user independent MSI prototype passes compile/readonly isolation/extracted125
hashes; original product/service/config not changed, no MSI install performed. Final85
artifacts/source/signature/version gates and actual paired acceptance pending. Earlier
planning-only/defaultOFF records are historical; no LAN Messenger production changes.

| Private helper85 compatibility | Windows receiver | Android sender | Evidence |
|---|---|---|---|
| Manual approval | Default ON; saved ON/OFF; local Accept required | Existing explicit request/pending wire retained | Code/Flutter/policy/config/native/wire checks PASS; actual paired/restart acceptance pending |
| Temporary code | Same reusable7200s volatile code; restart regenerates | Existing six-digit sender | Wire unchanged; real paired/restart test pending |
| Release identity | Final MSI/private EXE1.3.7/build85 | Final APK versionName1.3.7/versionCode2085 | Artifacts built/verified; no85 device install or paired acceptance yet |

2026-10-09 SubnetDesk manual approval default change PLANNED ONLY: user selected default
ON and remembered explicit ON/OFF across restarts. PLAN-SUBNETDESK-MANUAL-DEFAULT.md has
Windows persistence/startup/toggle/UI tasks, Both unchanged-wire review and acceptance.
Await explicit start; current84 still manual volatile/OFF by default. No application code,
build/install/security-setting changes this turn. Proposed Windows1.3.7/build85; Android
2084 retained unless actual Android/wire change needs revised scope.

2026-10-09 reconciled84 completion (supersedes in-progress records below): production
9a9337b/commonb56ada4; Windows tests19m14s and selected native/wire/hash43 PASS, runner3
PASS, full release native5m15s/UI107.6s/post-build Flutter106 PASS. Repeated in-process
MSVC setup inflated PATH; isolated builder-process fix/fresh retry worked, no global env
change. Windows84 staged exact backend/hash/version, user Esc stopped computer use before
automated replacement. New read-only check sees user/external Windows84 PID4420/exact path.
Android2084 full native6m27s/APK506.2s/stage/install-r PASS, signer/original2075/mic preserved.
Release Keystore synthetic and actual English home/method/manual explanation PASS; AOT
83 old Arabic wait present vs84 absent/new English key present. Real pending request,
code reuse/restart/lock, audible buzz/voice and other paired acceptance remain open.84 ZIP/
source archive/final output record follow-up incomplete; no all-requests/integration claim.

2026-10-09 SubnetDesk CB execution STARTED by explicit user "start", plus confirmed
hardcoded Arabic manual-approval prompt. Helper production9a9337b/commonb56ada4 implements
7200s reusable volatile code (success does not reset deadline/guesses), separate120s
guess window/cooldown and five-guess revocation, suspended availability still denies/hides
while preserving unexpired code. Native bounded0.6s buzzer with voice-priority/owned stop
and visible errors replaces Default Beep. Two forced Arabic UI statuses replaced by English
translation keys; no selected-language/security/credentials/user-chat mutations.
Early Flutter106, standalone policy11, fresh runner CTest3 PASS. Full Both private1.3.6/
build84 builds running, not delivered/installed/accepted. Android rebuilt for shared prompt
correction, not receiver parity or wire changes. Old83 observed home/listener remains active;
original apps/signing/service preserved. Earlier planning-only records superseded for code.

2026-10-09 SubnetDesk code choice resolved: user explicitly wants SAME reusable code for
multiple connections until two-hour expiry or receiver-app restart, not single-use. Plan
CB-01 updated; successful connects must not rotate/reset deadline/attempts. Proposed
locked/stopped behavior hides/denies but retains unexpired volatile main-process code;
New code and five-guess revocation remain security overrides, rate cooldown stays120s.
This is still PLANNING ONLY, awaiting explicit start; current83 unchanged120s/single-use.

2026-10-09 new SubnetDesk code/buzzer request PLANNED ONLY: two-hour/restart code,
user reports visual buzzer but interpreted no laptop sound. PLAN-SUBNETDESK-CODE-BUZZER.md
records small tasks/dependencies/status/acceptance/tests, single-use vs reuse clarification
pending and explicit start required. Current Windows runtime now verified83/PID23120/
listener21118/exact staged DLL, externally/user switched; previous82-close blocker resolved.
Current code still120s/single-use. Sound routes to Windows Default Beep and engine ignores
its result; file/services present, exact silent-output cause not proved. Plan dedicated
bounded tone/error visibility/voice arbitration, no OS sound settings change. No app edits,
new build/version/install. Android2083 unchanged; receiver-only changes need not rebuild it.

2026-10-09 FINAL SubnetDesk83 build/package checkpoint (supersedes in-progress records
below, NOT all-request acceptance): production85b9941/807f718/commonb56ada4; corresponding
source2787bf3. Windows native4m58s/Flutter74.2s/post-build101 PASS; initial VS18 Git-PATH
failure repaired process-locally, native retry1.59s. Selected native/wire/hash36 and fresh
runner CTest2 PASS. Android2083 installed/live English password-only/code/manual UI and
release-helper minimum-payload Keystore synthetic PASS; original2075/mic/data preserved.
Both binary/source artifacts staged; source-private gates1223+1354 PASS. Windows
ZIP9DE936FA...739AE7E, source2A1E23E2...8EAC6DB4; Android APK1536BB6E...92811B9C,
sourceB5426A75...019E07C8. Full hashes in outputs/SubnetDesk-helper-cm/SHA256SUMS.txt.
Windows still82/PID25660/listener21118/no session; old settings/auth dialog requires
human close. No security/auth/Firewall automation, no83 Windows main-code UI acceptance.
Human paired password/code/manual/restart/forget/trust/chat/voice/ring acceptance open.
No LAN Messenger production changes/integration, original service Stopped/Auto unchanged.

| Separate helper compatibility | Windows receiver83 | Android sender83 | Verification vs acceptance |
|---|---|---|---|
| Temporary code / manual | Interactive unlocked code auto; manual local opt-in, off after restart | Explicit code/manual selection | Native/wire/UI checks PASS; real paired request pending |
| Password only / saved | Wire3 after positive encrypted capability; password setting/no username | Empty-name encrypted fingerprint-bound password | Hash/wire/Keystore synthetic PASS; paired save/reconnect pending |
| Old account peers | Legacy wire0 retained for configured explicit account; password-disable gate applies | No automatic hidden account/fallback to old receivers | Additive defaults/no secret on old capability tested; actual old/new paired pending |
| Android receiver parity | Not applicable | Existing receiver behavior retained, no automatic code/unattended parity | No LAN Messenger wire change |

2026-10-09 SubnetDesk83 verification checkpoint: Windows native access12/password-only
encrypted loopback3/Android payload4/updater3/camera3/protocol6 PASS; common additive
wire4 PASS. Flutter101/101 PASS. Full Android1.3.5/code2083 build/stage/install-r PASS,
preserved helper signer/no-camera/16KB/exact-native gates PASS. Actual release-helper
minimum3-byte password-only Keystore synthetic test PASS; live Android home/password-only/
English three-method dropdown observed, no authentication submitted. Original2075/data/
mic grant intact. Windows full release/common hash tests and source archives pending;
Windows runtime still82, no paired session acceptance claim. Prior in-progress notes below
superseded only for these completed checks, not human security/auth/paired ring/chat tests.

2026-10-09 SubnetDesk HOME-ACCESS execution explicitly approved ("نفذ"). Separate
helper production commits85b9941/807f718 and commonb56ada4 implement normal-home
automatic code, password-only Unattended access, encrypted capability-negotiated wire3,
verified-device remembered-password compatibility and selected-language labels. No LAN
Messenger production edits. Final Flutter101/101 PASS; focused analyzer no errors,
60 legacy warning/info findings. Native tests and full private1.3.5/build83 Windows/Android
builds are in progress, not delivered/installed/accepted yet. Automatic code does not
enable OS service/prelogin/firewall/unlock; unavailable receiver fails closed. Historical
planning-only notes below are superseded, not evidence of build83 device acceptance.

2026-10-09 latest SubnetDesk plan correction: user requires PASSWORD ONLY, no username,
for Unattended access. HOME-ACCESS HA-04 revised and HA-04b added: Both auth/wire/Android
sender/saved-credential compatibility review, not hiding a required username in the UI.
Still planning-only, awaiting start; no app edits/build/install. Older username/password
requirements below are superseded for this upcoming private change, not build82 behavior.

2026-10-09 SubnetDesk UI correction PLANNED, not executed: user requires temporary code
always on main home and Settings > Unattended access username/password, with selected
language respected. Build82 code widget is only in incoming-only buildLeftPane, not normal
_buildNavigationSidebar; hardcoded new Arabic labels are a confirmed implementation defect.
Previous build/test PASS does not establish normal-home code availability. New small-task
plan PLAN-SUBNETDESK-HOME-ACCESS.md records dependencies, changed code lifecycle/default
policy, password configuration, regression and actual acceptance gates. Await explicit start
per planning-first workflow; no app edits/build/install/security settings in this turn.

2026-10-08 FINAL SubnetDesk private82 packaging/runtime checkpoint (supersedes older
build/testing-in-progress notes below): Windows1.3.4+82 full native8m50s/Flutter130.1s/
96 tests PASS, Android1.3.4/code2082 native4m18s/APK390.2s PASS. APK signer/identity/
no-camera/16KB/exact-native and both corresponding-source private-material gates PASS.
Windows ZIP87668879...33C8822, Android APK41F6876C...5F2F414F; output release82 notes
and SHA256SUMS contain full values. Featurebd628d9/common3bc0a6d; source archivea163ce7
includes test-only Java instrumentation fixf678dbd + records. Android helper installed-r,
original2075/data/mic grant preserved; actual release-helper synthetic Keystore test PASS
(not real paired native-JNI/reconnect acceptance). Old idle Windows79 closed normally,
new82 mainPID25660/listener21118/UIv1.3.4 verified; original service Stopped/Automatic intact.
Windows Firewall prompt needs human choice: no permission/security setting automation.
Local updated host Wi-Fi192.168.1.12, not historical separate discoveredpeer192.168.1.61.
Still pending human local opt-ins/acceptance and paired saved password/restart/forget/trust/
new-IP/code/manual/chat/ring/mixed-old-new checks. Not all requested work accepted; no
LAN Messenger integration/code/parity/key/branch/remote change or push. Plans/status local only.

2026-10-08 separate SubnetDesk private82 checkpoint: helper feature bd628d9, common3bc0a6d,
native access10/10 + updater3/camera3/credentials4/encrypted-LAN6, wire3/3 and Flutter96/96 PASS.
Android full native4m18s/APK390.2s and version/signature/no-camera/16KB/exact-native gates PASS;
approved side-by-side helper update installed1.3.4/code2082, original1.3.0/code2075 unchanged,
existing user mic grant preserved. Actual Keystore instrumentation driver crashed BEFORE tests
on missing release-shrunk test-only Kotlin Function1; Java framework-only test driver f678dbd
now rebuilding (no production change/rebuild needed for that). Windows full native PASS8m50s,
Flutter release still building; running Windows79 not switched yet. Real paired password/code/
manual/chat/ringtone acceptance remains, no all-requests-complete claim. LAN Messenger3.0.9
records and application/protocol/parity unchanged; no integration, push, security-setting change.

2026-10-08 LAN Messenger 3.0.9 final release (both platforms, matching version number by explicit
user request): "Messages only" presence mode (see the entry below for the original implementation)
is complete and user-confirmed on a real two-device LAN retest — a trusted contact's call rings
through under the mode; a non-trusted caller is declined with a distinct "Messages only" reason
instead of generic "Declined"; full Offline is unaffected. A real device bug was found and fixed
during this session's own retest: Android's `CallController.acceptInternal` had an older, separate
`!settings.allowIncoming()` gate (predating this feature) that ignored the trusted-call exception
and silently declined every trusted auto-answered call under the new mode; fixed to check the same
trusted mask `onInvite` already does. Windows had no equivalent duplicate gate and needed no
corresponding fix. Windows: `<Version>` 3.0.6 → 3.0.9, Release build 0 errors (one pre-existing
warning); full `tests/run.ps1` passes through every suite up to the already-known, pre-existing,
flaky `tests/group_membership.py` failure (unrelated — no suite touches calls or connection-mode
UI). Android: final signed build `-VersionName 3.0.9 -VersionCode 107`, all four ABIs, original
development signer unchanged (upgrade-safe). Outputs: `outputs/LanMessenger-3.0.9-Windows.zip` and
`outputs/LanMessenger-3.0.9.apk` with their SHA256SUMS manifests; this session's intermediate
`-messages-only-test` candidates are removed as superseded. See `windows/STATUS.md`,
`android/STATUS.md` and `PLAN-CALL-DO-NOT-DISTURB.md`. No push.

2026-10-08 latest SubnetDesk checkpoint (supersedes older pending-build statements):
chat-only Windows/Android80 builds and packages verified, not installed; physical memory
cleanup acceptance pending. Android Keystore credentials source d422290 plus hardening
a9eea0f: payload4/4, Flutter89/89, ARM64 native and internal APK81/signature/identity/
no-camera/alignment checks PASS; preflight81 not installed, hardening needs final rebuild
and Keystore/paired device tests. Optional code/manual access now wired in SOURCE:
encrypted post-trust capability probe, default password0 compatible, code1/manual2 gated;
libsodium code/nonce, volatile opt-in controls, Windows known-active-unlocked same-process
listener check, unauthorized CM decision-only card and backend network/IPC/output gates.
Policy7/7 and bridge generation PASS; compiler/Flutter verification in progress. No new
release/actual access acceptance claim. All requested work is not complete. Original apps,
service settings, permissions and signing preserved; LAN Messenger code/parity unaffected.
Own generated Windows Rust cache was verified/copied to C and old generated D cache removed,
with a D junction to the retained copy; source/outputs/private/app data untouched (~6.5GB freed).
See SubnetDesk chat/credential/access/contract plans; safe approved execution continues.

2026-10-08 "Messages only" presence mode implemented on both platforms (source only, not yet
device-accepted; Windows additionally build/test-verified, see below): chosen from the existing
Offline control (a chooser on click, not a new separate button) on both platforms, it keeps the
device Online (presence, messages) while auto-declining non-trusted incoming voice/video calls
with no ring; a contact holding an explicit trusted-call grant is an exception and still rings
through. The caller now sees a distinct "Messages only" reason instead of generic "Declined" (new
wire `DECLINE` body field + new `EndReason`/`MESSAGES_ONLY`, implemented identically on both
platforms). Windows: `dotnet build -c Release` 0 errors (one pre-existing warning); full
`tests/run.ps1` passes up through its last suite, which stops on the already-known, unrelated
`group_membership.py` transport-timeout failure recorded elsewhere in this file against a clean
HEAD worktree. Android: `android/build.ps1`'s real compile/D8/package pipeline completes with no
errors, stopping only at its final zipalign step because that step refuses to overwrite an
existing release APK from a prior session (a safety guard, not a failure) — not signed/installed
this session. No release, packaging, or device acceptance; see `windows/STATUS.md`,
`android/STATUS.md` and `PLAN-CALL-DO-NOT-DISTURB.md` for full detail and the remaining
device-acceptance checklist.

2026-10-08 approved SubnetDesk continuation: session-only chat memory implemented in helper
05a206db8f4cc5e729602bd464b206ba581b7ad2. Exact peer+connId identity, disconnect/snapshot/
outgoing error/reconnect/close/dispose cleanup of messages and selected draft, held-list cleanup
and late async receive guards. Fold/tab/voice-call end alone preserve active-session chat.
Logical application state removal, not forensic immutable-string/OS-memory overwriting.
Full Flutter89/89 PASS including16 memory/lifecycle tests; Windows frontend1.3.3+80 PASS149.0s,
staged distinct folder with verified unchanged no-updater DLL. Android APK80 build in progress.
Neither app runtime updated for chat; physical reconnect/network-loss acceptance pending.
Android saved-password Keystore store and temporary-code/manual-approval access modes remain
approved NOT implemented. User's reminder is correct: do not claim all requests completed.
See PLAN-SUBNETDESK-CHAT-MEMORY.md and the two credentials/access plans. LAN Messenger
code/protocol/platform comparison unaffected; no credentials/permissions/signing changes.

2026-10-08 SubnetDesk voice-start follow-up: Windows build79 main5476 has established phone
connection/actual CM23876. User's Failed to start voice call is directly matched by helper
PID16032 Android log: no RECORD_AUDIO permission -> recorder fail -> onVoiceCallStarted fail.
Helper1.3.3/code2078 granted=false/AppOps ignore; original1.3.0/code2075 is separately granted.
Read-only diagnosis, no permission/source/build/signing changes. Human helper microphone grant
and paired audible retest required. Windows ringtone79 and voice acceptance still pending;
transport alone is not audio acceptance. See DIAGNOSIS-SUBNETDESK-VOICE-20261008.md.
No LAN Messenger code/protocol/parity changes.


2026-10-08 SubnetDesk build79 runtime switch explicitly authorized by user. User closed78;
no established21118 session remained. Raw-path UI launcher initially resolved installed1.3.0;
detected by process path/UI, closed normally, no call tested on it. Explicit process:path
launch now runs build79 main5476 from Windows-x64-v1.3.3-build79-private, owning21118.
EXE hash/FileVersion1.3.3+79 and unchanged no-updater DLL verified. Visible UI native version
remains1.3.3. Windows Firewall access permission overlay appeared during phone inspection;
Computer Use stopped without acting on it. User must handle security prompt before paired
ring test. Audible79 acceptance NOT performed; no call auto-answer or audio-setting change.
Original service Stopped/Auto/path unchanged; installed files, Android APK/signing, frozen
archives and LAN Messenger code/protocol/parity unchanged. See platform status and plan.


2026-10-08 latest separate SubnetDesk Windows ringtone checkpoint supersedes pending-ring
acceptance below: actual running1.3.3+78 request UI/mute-off observed, but user hears no sound
(physical ring FAILED). Approved Windows-only repair replaces SystemSound with app-owned PCM
and checked native playback/stop; authoritative snapshot/add/event sync and lifecycle stop
completed. Helper4e4ba6a, frozen-source Windows frontend1.3.3+79 PASS132.1s, Flutter73/73,
CTest2/2; staged distinct candidate and binary/corresponding1199-entry private-gated source
archives complete. Backend1.3.3/no-updater DLL hash preserved; Android APK/native/signing and
frozen78 artifacts unchanged. Runtime NOT switched: main25332 still78, repeated user call
during preparation again tested78. Await session-safe direction and audible79 acceptance.
See PLAN-SUBNETDESK-VOICE-RING.md and outputs/SubnetDesk-helper-cm/RELEASE-1.3.3-BUILD79.md.
No LAN Messenger implementation/protocol/parity changes, no installed-file/service changes,
no push. Access modes/Keystore/reconnect chat-memory work remain separately pending.


2026-10-08 latest SubnetDesk checkpoint: user explicitly approved removal of View camera
on Both platforms, retaining screen/control and voice; LAN Messenger video is out of scope.
Camera controls removed and native session/login routes deny camera access; advertised
capability false. Windows1.3.3+78 native/Flutter release and Flutter65/65 pass; native camera3/3,
updater4/4 (feature enabled), chat attention5/5, encrypted protocol6/6, CM launch1/1 pass.
Versioned candidate/binary ZIP and1193-entry private-gated corresponding source ZIP complete
(helper12a8dac/hbb_common d797b73); hashes in outputs/SubnetDesk-helper-cm/SHA256SUMS.txt.
User approved switch: old1.3.1 closed normally without active session; visible new PID25332
owns21118 and UIv1.3.3. Windows Firewall permission dialog requires user handling; GUI automation
paused there. Original installed service Stopped/Auto/path unchanged; physical paired acceptance
pending. Android main dependencies plus libsodium/OpenSSL pass; actual ARM64 Rust release now
PASS2m02s (115 warnings recorded). JNI copy hash matches,16KB LOAD alignment/JNI exports checked.
Android build-only support committed in helper8a66332; Windows source12a8dac artifacts preserved.
Android APK release PASS1164.2s;1.3.3/code2078 helper identity, no CAMERA, signature/alignment and
rebuilt-to-stripped-to-APK native hash chain verified. Side-by-side install/startup smoke PASS;
original1.3.0/code2075/update timestamp unchanged. Helper7a45b44 corresponding Android source ZIP
1330-entry/private gate PASS; APK/source hashes in outputs manifest. Test signer preserved privately;
fresh helper mic/notifications denied, require user handling. Paired physical acceptance pending.
Original package/data/signing preserved. Three access modes, Keystore storage and reconnect chat-memory
cleanup remain pending implementation; prior execution approval stands. No LAN code/parity changes.

2026-10-08 checkpoint supersedes older awaiting-start entries: user approved all SubnetDesk
features, including permanent updater shutdown explicitly. Buzzer and Windows incoming ring
are implemented in helper source; focused Flutter17/17 and first native Windows Rust release
pass. Immutable update policy blocks FFI/scheduler and legacy Windows CLI/installers; updater
controls removed. Final builds/packages/runtime acceptance pending; running1.3.1 is unchanged.
Three access modes and Android Keystore credential save are approved, not implemented yet.
Android side-by-side candidate approved; scoped SDK/NDK dependencies prepared without altering
original Android app/data or LAN signing key. LAN Messenger code/protocol/parity unchanged.

2026-10-08 user approved SubnetDesk buzzer execution and a side-by-side Android candidate.
Implementation started; not built/device accepted yet. Microphone permission explicitly
approved and granted for installed SubnetDesk (granted=true/AppOps foreground); original
phone connected successfully to Windows candidate during retest setup. Audible retest pending.
New three-access-mode request (saved password/temporary code/manual approval) is plan-only,
awaiting start in PLAN-SUBNETDESK-ACCESS-MODES.md. LAN Messenger code/parity unchanged.

2026-10-08 SubnetDesk chat buzzer requested; Android sender -> Windows receiver first-stage
plan in PLAN-SUBNETDESK-CHAT-BUZZER.md. No implementation/build; explicit start still required.
User prefers no persistent chat history; no message/buzz storage added. Phone ADB diagnosis
now confirms Android RECORD_AUDIO granted=false/AppOps ignore and matching capture-failure
log at10:01:23. Permission unchanged; audible voice retest pending. See
DIAGNOSIS-SUBNETDESK-VOICE-20261008.md. No supplied login credentials retained in project files.
LAN Messenger code/parity, helper binaries and Android signer/install remain unchanged.

2026-10-08 SubnetDesk1.3.1+76 incoming dock visibility accepted by user: "ok now this is good".
Live evidence: Android .51 Established to candidate PID4052/.12:21118; automatically launched
child PID12188 uses candidate --cm and has a native window handle. Old service Stopped/Auto.
Initial incoming panel visibility accepted; manual fold/drafts/unread, paired chat, audible
Voice, DPI/multiple sessions and installed-service/prelogin/reboot behavior remain unaccepted.
Android password-saving remains plan-only; LAN Messenger integration/code/parity unchanged.

2026-10-08 SubnetDesk Windows native runner repair executed with user approval. Production
argument helper old0/17 -> fixed17/17; CTest1/1; launch policy2/2; Flutter53/53; full Rust and
Flutter Windows release builds pass. Local candidate1.3.1+76 (CLI1.3.1/exit0) staged and started
as PID4052, owning .12:21118; old installed service remains Stopped/Auto/unmodified. --cm now
reaches Flutter CM initialization instead of immediate exit1; idle/no-client probe then closes.
Actual incoming dock/chat/fold acceptance pending phone reconnect. No LAN Messenger/Android
implementation, wire, signing or installed-release replacement. Binary and corresponding-source
archives complete (source2aa0dc7 plus pinned hbb_common/WindowInjection, private-material gate pass).

2026-10-08 SubnetDesk dock acceptance FAILED after verified backend handoff: Android .51 has
an Established session to candidate PID1896 on .12:21118, but no CM process/window survives.
Candidate logs Failed to connect to connection manager; manual --cm probe exits1.
Native runner trims the last non-whitespace character (--cm -> --c), breaking its instance
allowlist. Repair/version/native regression plan prepared; no application changes or rebuild
during diagnosis. See PLAN-SUBNETDESK-WINDOWS-RUNNER.md. Old service remains Stopped/Auto.

2026-10-08 SubnetDesk temporary backend handoff explicitly authorized and completed on
192.168.1.12: original service is Stopped with Automatic startup/path unchanged; old server,
headless CM and tray gone. Candidate PID1896 owns TCP21118; native main window exists.
User reconnect requested; visible incoming dock/chat/voice acceptance still pending.
Earlier attempts had no dock while old backend was active. No installed binary/version,
LAN Messenger code/protocol, Android implementation, signing or release change.

2026-10-08 separate SubnetDesk Windows helper candidate: full Rust/Flutter/auxiliary builds pass,
policy2/2 and Flutter53/53 pass; isolated-data native startup returns1.3.0/exit0. Graphical/paired
acceptance pending; old installed SubnetDesk service is still Running/Auto and was not replaced.
Backend handoff requires user direction before session testing. Android credential-saving addition
is plan-only. No LAN Messenger code/protocol/parity/signing/release changes.

2026-10-07 SubnetDesk remains a separate helper, not integrated into LAN Messenger. Authorized
Windows work adds a visible, bottom-right foldable session/chat dock in its v1.3.0 source;
helper Flutter suite 53/53 and launch-policy 2/2 pass, full native build/device acceptance pending.
Android remember-password request is planning only (encrypted, opt-in, fingerprint-bound, forget
action), awaiting explicit start. LAN Messenger implementations, protocol, parity and releases
are unchanged by this work. See the two PLAN-SUBNETDESK documents and platform status records.

2026-10-06 UI/polish pass across both platforms (source only, not released/packaged — see
`android/STATUS.md` and `windows/STATUS.md` for full per-platform detail): Android gained
call-screen fullscreen video and a Direct connections IP refresh (manual button + optional
3-minute auto-refresh, re-probing the stored address and, on failure, sweeping the local subnet
for the same verified certificate — no wire/frame change). Windows gained selection-gated
conversation action buttons (hidden, not just disabled, until a conversation is selected). Both
platforms moved from the WhatsApp-green palette to a shared navy-header/blue-accent palette with
flat, pill-shaped buttons. Each change compiled/built clean on its own platform; none of this was
packaged, released, or device-accepted.

2026-10-06 user-requested LAN Messenger3.0.0 packages produced: Windows self-contained
x64 Portable (.NET9.0.9 included, app-local native video DLL), Android multi-ABI code99 with
original signer. Remaining audio work saved in local8506520. Packaged native138/138,
WindowsCallUi11/11, isolated-data portable startup pass. User reports camera shutter was
closed and now open; bidirectional image retest/listening/stress remain pending. Packaging
does not waive these acceptance gates. No push. Outputs in D:/LAN-Messenger/outputs.

2026-10-06 paired video evidence: phone image visibly reaches Windows in Connected/Video;
Windows camera preview/phone remote image black, cause unresolved. Camera off button inversion
found and fixed, WindowsCallUi 11/11. Bidirectional usable video, audio listening and stress
acceptance still pending; all earlier full-readiness claims remain excluded.

2026-10-06 paired continuation supersedes the selection blocker below: phone Direct connections
now selects Lap and ultra with explicit user approval. Both devices Online; Android-originated
voice-only call accepted on Windows reached Connected and cleanly ended after about 39 seconds.
This is signaling/connection evidence, not audible-quality or paired-video acceptance.

2026-10-06 Windows video completion execution: real consent-gated default-camera capture and local
preview now exist alongside remote rendering. Native video SDP was corrected to the shared single-VP8
m-line/index0 contract; sender reuse, errors, frame bounds and lifetime/generation cleanup were
verified. Initial voice fallback and mid-call upgrade UI/coordinator wiring were completed.
Windows Release 0 errors; call/video359/359; ABI39/39; real native generated transport138/138;
Windows call UI9/9; local physical camera preview/reopen2/2. Shared corpora113+38 agree. Full regression
still encounters the recorded pre-existing group_membership capability failure; later suites are run
separately. Android SM-A075F upgraded safely to original-signer2.2.71/code98 dev candidate with unchanged
first-install time. Physical Windows↔Android image/audio/control acceptance remains pending because
the phone's Direct connections selection currently exposes ultra, not Windows Lap. No final Windows
release or video parity claim. See windows/video-calling/EVIDENCE-WVR-COMPLETION-20261006.md.

2026-10-06 Windows call v2 regression repair (source/test only, not a release): two real-device call
failures are fixed, both latent v2 bugs that only became reachable once the CALLCAPS probe started
succeeding and the v2 enabler put every call on protocolVersion 2. (1) The SDP validator required the
m-line transport to be exactly `UDP/TLS/RTP/SAVPF`, while SIPSorcery 10.0.17 — the Windows adapter —
emits `UDP/TLS/RTP/SAVP`; the refusal surfaced as `EndReason.MediaError` through a `catch` that
discarded the exception. Both ports now accept exactly `SAVP` and `SAVPF` and still refuse TCP and
near-miss tokens. (2) `CallSignaling.Accept` returned a null body, so the controller's
`accept.B!["media"]` threw after the session moved to `Connecting` and before any snapshot — an
incoming call could be neither answered nor ended; the builder now allocates the body, as Android's
`Frame` constructor always has, and a v1 ACCEPT is still byte-identical. Accept ordering now sends the
ACCEPT before the state change and before the ring watchdog is cancelled, and a failed send ends the
call instead of stranding it; media failures record their cause instead of discarding it, visible as
a new `cause=` field and an `event=accept-failed` record in `call-diagnostics.log`. Wire change:
deliberate and paired — both SDP validators now accept two transport profiles instead of one, which is
a relaxation rather than a new frame type, and the shared corpus proves Android and Windows reach
identical verdicts on 113 records. Verification: Windows Release 0 errors; call/video 338/338 (was
324); shared frame corpus 113 records and capability corpus 38 records agree three-way; WindowsUi PASS;
`tests/run.ps1` PASS except `tests/group_membership.py`, which fails identically in a clean worktree at
HEAD `902e92d` and is therefore pre-existing and unrelated. The accept-path reordering has no automated
test — reaching it needs two paired live engines — so physical acceptance is still required on two
devices and no claim of working calls is made. Android changed only in the mirrored validator clause
and its fake's transport string. No release, version bump, commit or push. Detail and the full device
checklist: `windows/video-calling/TASK-CONTRACT-CALL-V2-FIX.md`.

2026-10-05 Windows receive-only video checkpoint (source/test build only): enabled the native
adapter behind ABI 1.1, added a VP8 receive-only m-line before offer, completed local SDP and ICE
handling, and added decoded remote-frame callback/rendering. Intended usable direction is Android
camera -> Windows; Windows webcam capture remains honestly disabled and probe/ringing remain
hardware-free. This also unblocks the fresh-grant caller-only recipient-control bar during a real
v2 call. Native bridge 39/39, call/video 324/324, Release build 0 errors (one pre-existing warning).
Updated Windows app launched, but no Android ADB endpoint was connected; physical image/control
acceptance remains pending. No release, Android/wire change, commit or push.
The Windows call shell was also unified so v1 fallback uses the new larger arranged layout and
explicitly labels video unavailable, rather than silently displaying the historical compact form.

2026-10-05 Windows recipient-control UI (source only): retained `Permissions...` and added a
separate ordered call-window bar for recipient Speaker, Camera on/off and Front/Rear. It is caller-
only, Connected-only, requires a fresh certificate-bound Slave grant refreshed every five seconds,
rechecks at click time and hides immediately after a failed refresh. Controller authorization was
corrected from the local Masters mask to the remote Slave-direction mask. Camera additionally
requires live video. Honest limitation: Windows still negotiates v1 voice because production video
is disabled, while `REMOTE_*` is v2-only; therefore the new controls intentionally remain hidden in
the current runtime until Windows video is enabled. Release build succeeds with 0 errors and one
pre-existing warning; focused call/video harness 324/324. Android/wire unchanged; no release/commit/push.

2026-10-05 Android final release 2.2.70/code97: the user accepted the installed 2.2.69 candidate
as stable and authorized final all-ABI packaging without a functional camera change. Final APK:
`D:/LAN-Messenger/outputs/LanMessenger-2.2.70.apk`, 23,184,456 bytes, SHA-256
`c405937d61d6a398492210b33d4774788777cfd43ce7d767841e3d7a32783a88`; original signer
continuity verified against 2.2.69, v2/v3, one signer. Focused release checks pass: call 440/0,
permission 40/0, recipient visibility 28/0, direct 34/0 and all video-contract suites. Known
limitation: a trusted Slave cannot start a new camera capture when its phone is already locked;
camera started during an unlocked call continues after locking. Exact 2.2.70 was packaged but not
reinstalled; physical stability acceptance carries from the identical 2.2.69 candidate. Windows
and wire unchanged; no push.

2026-10-05 Windows Masters/Slave permission UI (source only, not a release): Windows now has a
`Permissions...` entry. Masters shows certificate-bound local grants and lets the user edit/revoke
them through the existing trusted-call editor. Slave is read-only and shows verified session-only
`CALLGRANTS/1` answers with current, stale/offline and unknown states, refreshing online verified
peers automatically or on demand. Displayed remote status is informational and never authorization;
certificate mismatch/revocation removes it. This brings the directional list semantics into the
Windows source without changing Android or the wire protocol. Windows Release build: 0 errors,
0 warnings; focused call/video harness: 317/317. Native-window visual/device
acceptance remains pending because the UI-control session could not enumerate Windows app windows.
No package/release/commit/push.

2026-10-05 Windows-only Android-to-PC audio regression repair (source only, not a release):
uncommitted Windows changes had selected 8 kHz PCMU while the winmm path remained 16 kHz and
had reduced PCM frames from 640 bytes/20 ms to 320 bytes, matching the reported distorted,
choppy Android-to-Windows audio. Restored G722-first negotiation and the 640-byte 16 kHz/20 ms
contract. User listening then isolated continuing Lap/Windows-microphone gaps: Windows supplied
320 PCM samples as 320 RTP timestamp units although G722's RTP clock is 8 kHz, making each 20 ms
packet advertise 40 ms. The corrected mapping is 320 PCM samples => 160 RTP units; a focused
reflection check passes for G722 and the unchanged PCMU mapping. Also repaired an adjacent
malformed call-view event binding. Windows Release build passes with 0 errors (one pre-existing
warning). Android and wire are unchanged. Post-clock-fix audible physical acceptance remains
pending. No package, release, commit or push.

2026-10-05 follow-up listening: the corrected G722 RTP clock made Windows-microphone audio
"much better" and removed the severe cutting, but laptop capture remained low/not fully clear.
After fixed-gain trials remained slightly low, Windows source now uses bounded adaptive microphone
gain: RMS target 5000 for meaningful speech, 1x..12x limit, slow rise/fast fall, silence gate at
RMS 100 and 16-bit saturation. Optional diagnostics record timing/levels only; the captured run
showed stable 20 ms pacing and very low raw laptop input (RMS 58.8, peak 2267). Focused RTP/gain/
limiter checks and Release build pass. This does not claim noise suppression/AEC, and adaptive-gain
device listening remains pending. Android/wire unchanged; no package/release/commit/push.

2026-10-05 Windows-only native bridge repair: missing codec dependencies causing startup
AV and asynchronous empty audio SDP corrected. Native ABI 39/39, hardware-free readiness
24/24, audio offer/answer/teardown cycles 20/20; Release build 0 errors. No Android/protocol
change or parity claim. WVC-06/T02 Partial, WVC-08 blocked, production video disabled.
Full tests/run.ps1 exit 0; call-video 317/0. No push/release.
[Evidence and remaining gates](windows/video-calling/BRIDGE-CRASH-REPAIR.md).

2026-10-04 Windows video-call implementation pass (source only, **not a release**): the
managed v2 coordination layer is now implemented in Windows source and is
wire-compatible with Android's existing production video implementation — strict v2
parser and builders, `CALLCAPS`/`CALLGRANTS` engine responders, capability probe,
consent/actions/coordinator state machine, two-stage frame admission, v1-preserving
`CallController` integration, a `CallView` video stage with a clamped draggable preview,
all four trusted-call grant bits, and `PlatformTarget=x64`. Automated: Release build
0 errors, full `tests/run.ps1` exit 0, `--call-video-check` 317/0, and the shared corpora
agree across both platforms (107 frame records, 38 capability records, each also
matching a hand-authored expectation). **Parity is still not claimed.** There is no
production native video adapter, so **this build advertises voice only** and negotiates
v1: `PeerEngine.CallVideoSupport` defaults to false and `CallController.VideoEnabled`'s
getter is `videoEnabled && VideoMediaFactory != null`, so no assignment can make this
build claim VP8 without a backend — a peer probes, gets no CAPS reply, and offers voice
from the start instead of committing to a video call that could never produce a
picture. Ten
capability-honesty checks pin this, and were confirmed to fail against the earlier
`true`-by-default wiring. Section B (the native voice replacement) was deliberately not
started and voice stays on the proven SIPSorcery + G722 path; and there was no packaging,
no webcam, no DPI or renderer measurement and no two-device call. Windows `<Version>` is
still 2.2.42 and the shipped Windows release still contains none of this. Android code
and wire are unchanged by this pass. See
[Windows video calling plan](windows/video-calling/PLAN-WINDOWS-VIDEO-CALLING.md).

2026-10-04 Android locked/background calls: 2.2.69/code96 original-key ARM64 test
candidate installed on both phones. Trusted video acceptance no longer depends on
camera startup; notification action identity/threading/FGS presentation and stale
ring cleanup corrected; already-prepared camera continues across Activity pause.
Call440/0, permission40/0, recipient28/0, direct34/0, video-contract and lifecycle
guards pass. Actual USB automatic acceptance/background call observed. Full locked
notification acceptance and NEW locked-camera startup remain unverified/pending;
2.2.68 failed candidate superseded. Windows and wire unchanged; Wi-Fi fault unresolved.
See [Android locked calls](PLAN-ANDROID-LOCKED-CALLS.md).

2026-10-04 Windows planning review: rebuilt the
[Windows video-call continuation plan](windows/video-calling/PLAN-WINDOWS-VIDEO-CALLING.md)
against current source and retained evidence. Native separate-PC VP8/G722
feasibility passed; Windows production is still voice-only 2.2.42. Production
integration, real webcam/UI/lifecycle, grant-gated recipient controls and packaged
interoperability are pending. Android production video exists in current candidates;
no parity, Wi-Fi repair or new physical acceptance is claimed. Documentation only.

2026-10-04 Android recipient-control visibility checkpoint: recipient camera and
speaker controls appear only with the respective fresh grant from that device
to the caller (Slave direction). Unknown, failed, revoked and expired confirmation
hides controls; recipient-side enforcement unchanged. Signed ARM64 Android
2.2.67/code94 test candidate upgraded on both phones, including USB SM-A075F.
Permission40/0, visibility28/0, call422/0 and direct34/0 checks pass. Physical
call-screen acceptance pending; Wi-Fi fault unresolved. Windows/wire unchanged.
See [recipient-control plan](PLAN-ANDROID-RECIPIENT-CONTROL-VISIBILITY.md).

2026-10-04 Android feature checkpoint: optional Direct connections now restricts
application networking to selected verified identities and explicit IPv4 addresses,
with discovery disabled, encrypted saved selection, socket/call-candidate guards
and other contacts offline/queued. Android2.2.66/code93 ARM64 original-key test
candidate installed over existing data on both phones (SM-A075F over USB).
Direct34/0, call422/0, pacing28/0, permission36/0 and video-contract/lifecycle
checks pass. Device UI/native media and Wi-Fi stability acceptance remain pending;
the known SM-A075F disconnect fault is not claimed repaired. Windows has no new
direct-mode UI; LM4 unchanged and physical Windows pairing in this mode pending.
See [Android direct-connections plan](PLAN-ANDROID-DIRECT-CONNECTIONS.md).

Release decision 2026-10-03: user stopped investigation and requested Android
2.2.65/code92 final packaging, commit and push. Existing signer; all supported
ABIs. Known issue: SM-A075F Wi-Fi disconnections remain unresolved and physical
stability acceptance failed. This is a user-authorized release, not a verified
Wi-Fi repair. Windows remains unchanged; no new wire or parity change.


Wi-Fi investigation checkpoint 2026-10-03: Android2.2.64/code91 full-function
diagnostic candidate installed on both phones with original signer/data retained.
SM-A075F still loses Wi-Fi association; SM-S908E does not show this issue.
Multicast/delivery isolation and pacing have NOT confirmed a repair. CallCheck
422/0 and pacing28/0 pass, but physical stability acceptance failed. Release held;
Windows unchanged and no wire/parity change. See Android status and Wi-Fi plan.

Current checkpoint 2026-10-03: Android 2.2.57/code84 ARM64 signed test candidate
is installed on SM-A075F and SM-S908E with original signer and unchanged first-install
times. Android has Masters (devices I granted access to) and Slave (devices granting
me access) menu lists, backed by optional verified TLS CALLGRANTS/1 queries.
Two-phone list direction, partial reverse grant and automatic revoke removal passed;
test grant was removed afterward. Permission TLS checks 36/0, CallCheck 422/0 and
all video-contract suites pass. Remote status is informational, session-only and
timestamped; offline/legacy status is last-known/unknown, never authorization.
Android source also includes caller-only recipient camera on/off/front/rear and
speaker controls, trusted initial video acceptance and video detach cleanup fixes.
Earlier physical video streaming succeeded, but latest complete call-control
acceptance remains pending following recipient Wi-Fi/signaling loss. Windows
unchanged: voice-only, no menu/query implementation or production video parity.
Actual new-query Windows interoperability not physically repeated; parser review
and simulated-legacy TLS fallback passed. This is not a final release.
Older checkpoints below are historical and superseded where they conflict.

Trusted-call/icon source checkpoint 2026-10-03: the user-supplied artwork is now
the Android adaptive/legacy launcher icon and Windows executable/window/tray icon.
Both platforms persist certificate-bound per-contact trusted-call scopes and expose
an explicit **Trusted call access** control; the implemented scope is voice
auto-answer only. Revocation, remote forget, contact deletion and delete-all clear
the grant. Android 2.2.45/code72 ARM64 signed test candidate built with the original
certificate (`LanMessenger-2.2.45-trusted-dev.apk`, SHA-256
`e801f62792e3916900cf27c61da880b8842596541a0bb82a5595d12cdd8bb07a`).
CallCheck 422/0 and Windows Release build/publish passed. Android 2.2.46/code73
adds certificate-bound trusted video auto-accept and remote speaker routing; its
APK build/signature checks pass and a physical camera source initialized on an
SM-S908E, but the complete two-phone call has not yet been repeated and remote
front/rear camera switching remains pending. This is not a release or
physical-device acceptance. Remote speaker and camera control, video auto-answer,
and Windows production video remain pending; there is no new wire command yet.
See [trusted-call/icon plan](PLAN-TRUSTED-CALL-ACCESS-AND-APP-ICON.md).

Latest Android cleanup-fix test candidate is 2.2.44/code71 (ARM64), installed over
2.2.43 with original signer and unchanged first-install time. Reproduced/fixed
receiver video-track double disposal; three native adapter lifetimes and next
voice-only setup/cleanup pass. Packaged two-phone video remains pending; Windows
2.2.42 remains voice-only. This changes no wire contract or achieved parity.
See android/video-calling/CLEANUP-FIX-HANDOFF.md. Older snapshots below are historical.

Latest installed Android TEST CANDIDATE is2.2.43/code70, arm64, original signer;
the earlier stable pair in the release table below remains2.2.42. Candidate
startup/data-visible retention and separate physical camera adapter checks pass.
Connected packaged UI/video and Windows pairing remain unaccepted; no final
cross-platform video parity claim. See Android A3-A4 candidate handoff.

In-progress Android candidate 2.2.43/code70: video coordination, controls,
renderers and lifecycle are in source, not yet packaged-device accepted.
Windows production video/R05 remain pending; Android-to-old-Windows calls remain
voice-only. No new release/parity claim. See Android A3-A4 candidate handoff.

Android A07 source checkpoint: authenticated capability probe and call/channel/
replay boundaries added; video advertising remains disabled pending full v2
orchestration. Real TLS/fake-media checks passed; no physical production video or
release compatibility/parity change. Latest full regression reached Windows UI
and failed occupied-port reservation; current-source peer/group interoperability
checks passed separately. [A07 handoff](android/video-calling/A07-SIGNALING-HANDOFF.md).

Latest Android A06 source adds the separate secured VP8 adapter and explicitly
gated camera operations. It is not yet wired to production signaling/UI and has
no physical-camera acceptance or signed release. JVM adapter boundaries 41/0;
compatibility/parity claims remain unchanged. See
[A06 media handoff](android/video-calling/A06-MEDIA-HANDOFF.md).

Android video source checkpoint 2026-10-03: consent policy/commands and service
EGL/media interface foundations implemented. Java/DEX build, call checks 408/0
and explicit video foundations 289/0 passed; full regression stopped on disk
exhaustion. Actual production video media/controller/UI and signed candidate are
not complete. No release compatibility/parity change. See
[Android phase handoff](android/video-calling/A2-RESOURCE-HANDOFF.md).

Video feasibility update 2026-10-03: test-only Windows native/physical Android
generated VP8 pairing passed both directions with G722 and isolated video failure
continuity. Neither production release has video; compatibility/parity and
current 2.2.42 release claims are unchanged. Details:
[paired feasibility](windows/video-calling/PAIRED-FEASIBILITY.md).

Reviewed 2026-10-03. Current releases are **Windows 2.2.42** and **Android 2.2.42** (versionCode 69) — numbered to match by explicit user request, not because the platforms share a version scheme; releases remain independent and this is the first time the two numbers have ever lined up. See the feature comparison below for the actual per-feature state.

## Working arrangement

G1–G3 offline product controls are implemented in source and included in the 2.1.1 Android APK, but not in the Windows 2.1.0 or prior Android 2.1.0 release packages. Windows toolbar/tray and Android people-menu/notification controls share their respective engine transitions. A separate persisted default-Online request is distinct from actual state (bind failures remain Offline and can be retried). Go Offline enforces a strict no-LAN boundary while retaining local history, contacts, groups, cached attachments, partial transfers and queued direct/group sends; in-flight transfers interrupt and resume on reconnection. Remote presence ages out after approximately 12 seconds. Android uses one service-owned engine: actual Offline is bound-only/non-foreground while the Activity is bound, and engine-load/network-bind failures clear the started-service lifetime so it may stop after unbind; foreground and multicast lock are held only while networking. Its connection preference does not change people-list filters. LM4 protocol and compatibility are unchanged. Historical source-based Android physical-device/two-device LAN checks passed for both transfer directions and ADB service cleanup; these were not performed on the packaged 2.1.1 APK. Device acceptance of that APK remains pending.

- One repository at `D:/LAN-Messenger/source` and one shared development branch, currently `master`.
- [Windows status](windows/STATUS.md), [Android status](android/STATUS.md), and this comparison are the current platform records. `HANDOFF.md` is historical context.
- Releases and build/test output live in `D:/LAN-Messenger/outputs`. Do not duplicate the source tree.
- Label new work Windows, Android, or Both. Update the affected status and this comparison when behavior or compatibility changes.
- A platform UI change does not force a release on the other platform. A shared protocol change needs review and interoperability tests on both.
- Separate implemented behavior, automated verification, and acceptance on a real device.
- For new requests, plan first. Do not implement or build a release until the user explicitly asks to start.

## Current releases

| Platform | Release | Latest change | Verification |
|---|---|---|---|
| Windows | 2.2.42 (current; numbered to match Android by explicit request) | Real-device bugfix pass, same day, from the user's first actual manual use of the packaged build: (1) clicking "Call" froze the whole app ("Not Responding") because the Call button's click handler ran `CallController.StartCall` directly on the UI thread, which blocks on a synchronous TCP+TLS connect inside its transport factory — fixed by moving the call onto a background thread; (2) no ringtone at all for an incoming or outgoing call — first fix attempt (a repeating `SystemSounds.Exclamation` cue, the same mechanism used for message notifications) **did not work in practice**: the user confirmed it was still silent on real hardware despite a sound file being assigned to that event in the registry. Replaced with a new `CallRingtone.cs` that synthesizes a real two-tone ring and plays it directly through `CallAudioPlayback`, the same winmm output path real call audio already uses, instead of depending on any OS sound-event mechanism. Neither automated tests nor the `windriver` console-driver call test could have caught either original bug (the driver calls `CallController` directly, bypassing the WinForms UI entirely), and the ringtone fix itself has no automated coverage either (no WinForms UI test exists for calls) — a clean build is the only automated signal for it. See `windows/STATUS.md`'s 2026-10-03 bugfix entry for the full account. Plus everything below: first Windows release to package real voice calls (`CallController`/`CallProtocol`/`CallSignaling`/`WebRtcCallMedia`, SIPSorcery+G722), **verified by a real two-device LAN call against a physical Android phone, both directions** (Windows→Android 33.5s, Android→Windows 15.4s) confirming G722/SDP negotiation converges with Android's libwebrtc; one real bug found and fixed by that test (`SecureChannel`'s 6-second handshake timeout bleeding into the long-lived call-signaling stream, fixed with `UseLongLivedTimeouts()`); plus everything from 2.2.0 (Voice Messages Phase 2) | `dotnet build -c Release` (0 errors, one pre-existing benign warning) and `dotnet publish` succeeded; full `tests/run.ps1` suite passed clean (exit 0) against the intermediate (bug-1-fixed) build; the final ringtone-replacement build was only build-verified, not re-run through the full suite (no test covers this code). Republished (same version, no bump — this corrects a just-shipped release) as `outputs/LanMessenger-Windows-2.2.42.zip` (7,210,458 bytes, SHA-256 `a3975ac0acff78a3c59dbd64a6c6985f25a70f2307155e2fd7a1cdffff6f0d87`; manifest: `outputs/SHA256SUMS-Windows-2.2.42.txt`). **All fixes confirmed by the user on real hardware** ("yes both fixed, ringing works now"); `CallView.cs`'s UI still does not visually match Android's reference call-screen design |
| Android | 2.2.42, versionCode 69 (current; see `android/STATUS.md` for the full 2.2.7-2.2.42 history: voice calls, call-screen redesign, media-preview thumbnails, compose-row icons with camera/gallery video support, a 2026-10-02 crash fix for `RECORD_AUDIO` not being granted when the foreground service starts, and Messenger-style call-history entries in chat) | Same-day fifth pass on voice-message replay, after three straight attempts at reusing the same drained `AudioTrack` all failed on the user's device: `VoicePlayer` now exposes `isFinished()`, and `togglePlayback` routes a finished player through the same "build a brand-new player" path used for a different message, instead of trying to resume the old `AudioTrack` in place — this is exactly what leaving and re-entering the conversation already did reliably. Otherwise identical to 2.2.5/2.2.4/2.2.3: WhatsApp-style icon buttons (▶/⏸/⏹/🎤), draggable seek bar, sender's own sent voice message renders as a proper player. Plus everything from 2.2.2/2.2.1/2.2.0/2.1.1: Voice Messages Phase 1 (A01-A11, in source — see the Feature comparison below; platform-local only, interoperability not yet verified), Offline controls G1-G3, 2.1.0 ownership transfer, 2.0.1 carryover | Locally built and signed APK (`outputs/LanMessenger-2.2.6.apk`, 131,415 bytes, SHA-256 `72c29da9…`; manifest: `outputs/SHA256SUMS-Android-2.2.6.txt`). Original-key signer continuity confirmed directly via `keytool -printcert` (byte-identical certificate SHA-256 to 2.2.5/2.2.4/2.2.3/2.2.2/2.2.1/2.2.0/2.1.1) and `apksigner verify` (v2/v3, one signer). Built by running `android/build.ps1`'s exact pipeline manually (its own pre-existing, unrelated stderr-abort issue is noted in `android/STATUS.md`); every tool, path and signing input was still the project's own. Real-toolchain `javac`/`d8` compile clean; still awaiting device re-testing on the same phone that surfaced this. |

Windows 2.2.42 interoperates with Android 2.2.42, and both remain wire-compatible with the 2.0.x pair for any group that has never had its membership changed and never had its ownership transferred — see below. New direct-to-destination manual downloads require at least 0.8.7 on both peers; platform releases are independent and do not imply feature parity. Voice calls now have a packaged release on both platforms, **and interoperability between them is verified** by a real two-device LAN call in both directions (see the release table above) — unlike Voice Messages below, which still has no actual cross-platform send/receive test run. The sender-sees-own-voice-as-player, drag-seek-bar, and icon-button UX changes in Android 2.2.2 through 2.2.6 are Android-only; the Windows 2.2.0+ source still deliberately does the opposite on the first two points (see `android/STATUS.md`'s 2.2.2 entry) and has not been asked for parity yet. Voice Messages (the separate, older text/audio-clip feature, not voice calls) has a packaged release on both platforms (Windows 2.2.0+, Android 2.2.0+), but **interoperability between them is not yet verified** — that's Phase 3 of the shared Voice Messages plan, not yet started; both sides use the same marker filename and WAV format by design, but no actual cross-platform voice-message send/receive test has been run.

2.0.0 shipped group membership no longer fixed after creation: `Members` is now a live roster that shrinks when someone leaves and grows when the owner adds someone, propagated to every active member as a versioned snapshot (new `MEMBERSUPDATE` frame) so a device that's been offline through several changes catches up in one step rather than replaying each one. Any growth (a direct add or Re-invite) requires a **fresh, live capability check** of everyone who'd be in the group afterward — a past success is never trusted as durable, since the same device could have been downgraded or restored from a backup since. A group that's never been mutated stays on the exact old wire shape, so an unrelated, not-yet-updated device is genuinely unaffected; only a group that has actually changed requires every device in it to be current. Already-saved groups migrate once, automatically, from the old shape where a departed member sat in the member list and a separate flag at the same time. See [PLAN-GROUP-MEMBERSHIP.md](PLAN-GROUP-MEMBERSHIP.md) for the full design.

2.0.0 also briefly shipped a join-request feature (any verified contact of a group's owner could ask to join, with an owner accept/ignore queue). **That feature was removed** by explicit request in 2.0.1 — the wire frames, storage rows, engine methods and UI it added are all gone from both platforms; the mutable-membership foundation above is unaffected and remains fully in place. A device still running the exact 2.0.0 build that shipped join-requests will simply never get a response to a `JOINREQUEST` frame it sends (same tolerance as any other frame an older/newer build doesn't understand) — group messaging, add, and re-invite are unaffected. Two further, unrelated UI changes landed alongside the removal: "Delete conversation" is labeled "Leave group" when the target is a group (it was always actually a leave, never a real delete, and the old wording incorrectly implied verification was revoked), now reachable both from the conversation list and from inside an open group chat; and Android gained a "Hide groups" side-menu toggle, mirroring the existing "Show offline users" toggle.

**2.1.0**: group ownership can now be handed off. Previously the owner was fixed forever and the UI didn't actually stop them from leaving their own group — doing so silently orphaned it for everyone else (nobody was ever told, and since only the owner could change membership, the roster was permanently frozen). Now, "Leave group" for the owner of a non-empty group shows a "Choose a new admin" picker instead of the normal confirmation; picking someone calls the new `TransferOwnership`, which requires a fresh, live capability check (`CAPS>=2`) of *every* current active member — refusing outright, nothing changed, if anyone can't support it or hasn't finished onboarding yet. The owner's own departure is deferred (shown as "Leaving — waiting for members to catch up", composer disabled) until every other member has actually caught up to the handoff, not just the incoming owner — the old owner stays the sole delivery/leave-acceptance authority for that one change in the meantime, via a durable `pendingOwnershipHandoff` record that survives an app restart. This mirrors the existing versioned-snapshot convergence guarantee rather than inventing new trust machinery; see [PLAN-GROUP-OWNERSHIP-TRANSFER.md](PLAN-GROUP-OWNERSHIP-TRANSFER.md) for why a simpler "wait for just the new owner" design (an earlier draft) doesn't work, and for the accepted limitation that remains (a member who never comes back online blocks the departure indefinitely — a signed, relayable handoff proof would remove this, but is a separate future enhancement, not built speculatively). A group that's never had an ownership transfer is completely unaffected for old builds; only a group that's actually used this feature requires every device in it to be current, same shape as the existing membership-mutation compatibility split. An owner-only group still leaves with a plain, immediate local delete — nothing to hand off.

## Feature comparison

| Feature | Windows | Android |
|---|---|---|
| Discovery, verification, queued messages, delivery/read state | Implemented | Implemented |
| Groups, avatars, unread count | Implemented | Implemented |
| Clear chat locally while retaining contact/group and user-saved file | Implemented | Implemented |
| Delete conversation: forgets a contact (revokes verification, removes peer record); labeled "Leave group" for a group (always just a leave, never a real delete) | Implemented; right-click a conversation row | Implemented; long-press a conversation row |
| Delete app data: wipes every conversation/contact/group/attachment, keeps identity/name/avatar | Implemented; toolbar button | Implemented; side-menu item, also resets daily upload usage |
| Forgetting a contact also notifies them: their verification of you is auto-revoked, with an on-device notice | Implemented | Implemented |
| Leaving a group lets the owner see who departed and re-invite them back into the same group | Implemented; "Re-invite" in Members dialog | Implemented; "Re-invite" in Members dialog |
| Group membership can change after creation (not just re-invite): live roster, versioned propagation, migration of old-shape saved groups, a live capability check before any growth | Implemented | Implemented |
| Group ownership can be handed off; the owner must do so before leaving a non-empty group (owner-only groups still leave with a plain local delete) | Implemented | Implemented (not yet device-verified) |
| Blue online / gray offline presence | Implemented | Implemented |
| Go Online/Go Offline control (strict no-LAN Offline; local history, queued direct/group sends and resumable transfer partials retained; persisted default-Online request separate from actual state/bind failure) | Implemented in source, not in Windows 2.1.0 package; toolbar and tray share transition and show Retry online after bind failure; Refresh/Add by IP disabled Offline; Close hides to tray, Exit terminates | Included in Android 2.1.1 APK, device acceptance pending; people menu and notification share one service-owned engine; Refresh/Add by IP disabled Offline, verification explains Online requirement; Offline bound-only/non-foreground while Activity bound; foreground/multicast only during networking; `START_NOT_STICKY` avoids OS-driven restart |
| "Messages only" presence mode: stay Online (messages/presence as normal) while auto-declining non-trusted incoming voice/video calls with no ring; a trusted-call-grant contact is an exception and still rings through; the caller sees a distinct "Messages only" reason instead of generic "Declined" | Implemented, released as 3.0.9, device-confirmed (2026-10-08); chosen from the existing Offline control's click chooser (`ConnectionModePrompt.cs`); backend (`CallSettings.AllowIncomingCalls`) pre-existed, this adds the UI, the trusted exception, and the caller-visible wire reason; user's own two-device retest confirms the trusted exception rings through | Implemented, released as 3.0.9/code107, device-confirmed (2026-10-08); same chooser from the people-menu connection button (`PeopleListView.showConnectionModePrompt`), superseding the old standalone "Allow incoming calls" switch; real-device retest found and fixed a second, independent admission gate inside `acceptInternal` that ignored the trusted exception (see `android/STATUS.md`); user's own retest after the fix confirms a trusted contact now rings through |
| People-screen side menu | Not implemented | Implemented on Android; Profile and About live in it |
| Hide offline direct peers in the people list | Not implemented | Implemented on Android as an Android-local persisted `Show offline users` flag, default off; a people-list display filter for direct-peer rows only; it does not change engine state, routing or the wire, and deep links and open chats bypass the list rather than being filtered |
| Hide all group rows in the people list | Not implemented | Implemented on Android as a separate Android-local persisted `Hide groups` flag, default off, mirroring the offline-peer filter exactly (display-only, engine/wire unaffected, deep links and open chats bypass it) |
| Attachment draft followed by explicit Send | Implemented | Implemented |
| Automatic inline ordinary photos | Implemented within preview/codec limits | Implemented within preview/codec limits |
| Ordinary attachments up to 1 GiB; Fast offers up to 1 TiB | Implemented | Implemented |
| Manual Download asks destination, writes one receiver copy, Open launches it | Implemented | Implemented; destination provider must support seeking |
| Fast payload plaintext with authenticated TLS control | Implemented | Implemented |
| Manual download resume at 256 KiB boundaries | Implemented | Implemented |
| Background operation | Tray process until Exit | Foreground service subject to OS/battery limits |
| Built-in camera capture | Not implemented | Implemented |
| Initial show newest 10 messages, load 20 older on upward scroll | Implemented (paged, per-conversation view state) | Implemented at UI level |
| Attachment-thumbnail cache across chat changes | Implemented; 16 MiB reference-counted LRU, skips non-image files | 16 MiB Activity LRU cache |
| Retain unchanged cards on status updates | Implemented | Visible cards are rebuilt when the view signature changes |
| Keep complete UI trees for multiple active chats | Not implemented | Not implemented |
| Daily aggregate upload tiers: unlimited below 2 GiB, then 30/20/10 MiB/s at 2/5/10 GiB | Not implemented by earlier Android-only scope | Implemented |
| Comprehensive anti-flood policy | Not implemented beyond basic connection/transfer limits | Not implemented beyond basic limits and daily upload policy |
| Voice messages: record, send, receive and play short voice clips (reuses the existing encrypted Normal attachment store; no new wire frame) | Implemented in source (Phase 2, W01-W11, WT01-WT06 all written; WT04's exact admission-ordering edge case untested) | Implemented in source (Phase 1, A01-A11, AT01/AT02/AT06; AT04 partial, same untested edge case as Windows; AT03/AT05 not attempted, no confirmed audio device in this environment) |
| Photo/video attachments: Messenger-style single-thumbnail rendering (no filename/size line or buttons once a preview exists), fullscreen view with a single download control, video gets a first-frame thumbnail + play-disc with single-tap inline playback and double-tap fullscreen | Not implemented (Windows still shows the ordinary generic file card plus thumbnail, no video preview) | Implemented and device-verified two-device, both directions (see `android/STATUS.md`'s 2026-10-02 entry); Android-only, UI-only, no wire/storage change |
| Compose row: Messenger-style icons (+/camera/gallery/mic/send), camera icon offers Photo or Video capture, gallery icon picker accepts photo or video | Not implemented (Windows compose row is unchanged text-labeled controls, photo capture/picker only) | Implemented and device-verified (see `android/STATUS.md`'s 2026-10-02 "Compose row" entry); Android-only, no wire/storage change |
| Voice calls (real-time audio, WebRTC-based) | Implemented in source (`CallController`/`CallProtocol`/`CallSignaling`/`WebRtcCallMedia` etc., SIPSorcery+G722); **verified working cross-platform by a real two-device LAN call, both directions** (see `windows/STATUS.md`'s 2026-10-03 entry); not yet in a packaged release; `CallView.cs` UI does not yet match Android's reference design | Implemented and shipped (release 2.2.42); same cross-platform call test confirms wire/codec interop with Windows |
| Call history entries inline in chat, Messenger-style ("You called X", "X called you · duration", "Missed call") | Implemented (`CallLogMarker.cs`/`PeerEngine.AppendCallLog`), device-verified in the same cross-platform call test | Implemented and device-verified, both sides, real multi-call test (see `android/STATUS.md`'s 2026-10-02 "Call history entries" entry); purely local per-device annotation, no wire/protocol change |

Automatic ordinary images are the exception to destination selection and use an app-private cache. Fast image offers remain manual.

Offline automation (not device acceptance): Android SDK source compilation and full `tests/run.ps1` (including Windows native UI and cross-platform `tests/offline_lifecycle.py`) passed with SDK 9 MSBuild and in-workspace test output. The loopback runner checks accepted idle socket closure, Offline gating, delayed avatar/group work, interrupted Fast/ordinary/cache transfers, partial stability, integrity and duplicate-free retry. One earlier full-suite 16-member capability stress failure passed on isolated rerun and final full rerun. A 2.1.1 APK has since been built, signed and independently verified (see Current releases above). Windows source-only Offline controls have no Windows 2.1.0 package acceptance; Android 2.1.1 APK device/emulator acceptance is **Pending-Unavailable**. Historical Android source-based two-device Offline checks passed but do not constitute 2.1.1 APK acceptance; remote peers age out after approximately 12 seconds, not instantaneously.

Voice messages (in source on both platforms, not released): record/send/receive/play short voice
clips per `plan-v003` — see [windows/STATUS.md](windows/STATUS.md) and
[android/STATUS.md](android/STATUS.md) for the full write-ups. Both platforms' implementation
tasks (W01-W11 / A01-A11) are code-complete and pass their full local regression suites with
zero regressions; both used real compile/build verification throughout, not blind ports. A real
duplicate-Send bug in the draft registry's crash-boundary reconciliation was found during the
Android verification pass and fixed on **both** platforms in the same session (see either
status file's A05/W02 entry). Remaining on both: the scheduler's exact 3-consecutive-voice-then-
1-image admission-ordering (WT04/AT04's untested edge case, deliberately not forced black-box
against real async timing), device-lifecycle interaction tests needing real/simulated audio
hardware (Windows got WT03/WT05 coverage because its sandboxed environment happened to expose a
real `waveIn`/`waveOut` device; no Android equivalent has been confirmed here), and manual
two-device acceptance on physical hardware. **Platform-local only; interoperability between the
Windows and Android implementations has not yet been verified** (Phase 3 of the plan, not yet
started) — this row will be revised once both platform exit gates and the integration phase
complete.

## Performance and compatibility limits

Message records are resident in each engine's memory. Windows 0.8.9 renders only the newest 10 messages and pages backward, but `PeerEngine.Messages` still scans engine-held records; it is not a disk query for only 10 records. Measured before/after (tests/MeasureWindows, loopback): the 112-message chat opened in 8 ms on 0.8.8 and 2 ms on 0.8.9, so scanning was never the dominant cost and no engine recent-message index was added (plan W07). There is no fully implemented "ask only for new records" path across all UI/storage flows.

The automatic-photo legacy paths differ: Android has encrypted FETCHSTREAM with 256 KiB resume, while Windows uses FETCH with 100 MiB cached segments. The new manual FETCHDIRECT path works on both.

## Proposed work, not implemented

1. Confirm the Windows 0.8.10 rendering, paging, and repaint behavior on the affected PC/DPI setup; check large-chat opening and throughput on real LAN hardware.
2. Add a Windows engine recent-message index only if real-device measurements later show message scanning dominating open time (deferred by the finished pagination plan with recorded evidence).
3. Measure and consider retention/update of active chat UI on both platforms (Windows now caches up to 3 recent chats' cards; Android still rebuilds visible cards on signature changes).
4. Add Windows upload tiers only if the user expands the previously Android-only scope.
5. Validate Android destination choice, pause/resume, Open, background operation, and throughput on physical phones.

The repository has a GitHub origin. Recent release commits are local; no push was made for those releases. Remote refs were not refreshed for this status audit.
