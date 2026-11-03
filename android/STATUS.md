# Android status

2026-10-10 build88 verification: flutter analyze 0 errors (321 pre-existing info/warning
lints unchanged in kind); flutter test 141/141 PASS including all 5 new
android_outgoing_only_test.dart cases. Built with existing preserved candidate debug
signer (SHA256 43e19ba2d0d80033f363eb733efcef4d33dd0ab0bb6b06f1115cd71e47057c52, matches
build85); versionName1.3.7/versionCode2088. aapt dump badging: exactly INTERNET,
ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, RECORD_AUDIO plus the harmless self-signature
permission DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION; no hosting service/receiver, only
library-injected boilerplate (image_picker FileProvider, androidx-startup,
ProfileInstaller, disabled GMS stub). APK SHA256
86B9E1C44F879C8BB11DD524EDCA27E89528EDB44EA900068609991B4EE48824, copied to
D:\SubnetDesk-Helper\output\SubnetDesk-Helper-1.3.7-build88-Android-arm64-private.apk.
Device acceptance AT-02 on physical Samsung SM-S908E: adb install -r upgrade from85 to88
without clearing data PASS, app launches clean (no crash, no FATAL in logcat). Windows-
to-Android control attempts PASS (refused/no effect) in three states: immediately after
upgrade, after force-stop+relaunch, and after a full phone reboot with the app not
auto-started (netstat shows no listener on 21116-21119; Windows sender got
ConnectionRefused on 21118). Old build85 prefs are inert, consistent with removed
components. Not yet covered this session: explicit check of a previously-enabled
receiver-style setting carried over from build85, dedicated fresh-install (uninstall
first) permission-prompt-timing check, and the positive-path Android-to-Windows control
session. Not committed yet, pending approval.

2026-10-10 Android outgoing-only controller (plan-v002, sha256:0136befe...1c550) CODE COMPLETE,
not built/installed. Baseline: active checkout D:\SubnetDesk-Helper branch codex/subnetdesk-visible-cm
@4bd89d8; Android sources byte-identical to build85 android-source archive except CRLF;
package com.zibochen.subnetdesk.helper, 1.3.7/versionCode2085, helper signer 43e19ba2...57c52.
Pre-existing unrelated: dirty libs/hbb_common submodule; untracked status/baseline files.
Prior OpenCode session made no source changes after the freeze; all work below is new.
Hosting removed: BootReceiver, MainService (mediaProjection FGS + FFI.startServer),
InputService (accessibility), FloatingWindowService, PermissionRequestTransparentActivity,
KeyboardKeyEventMapper, VolumeController, accessibility/floating resources deleted; manifest
has no service/receiver. ffi.kt no longer declares init/startServer/startService/
onVideoFrameUpdate/refreshScreen, so no Kotlin path reaches native LanServer::start (the
only Android route to the control listener and lan::start_listening discovery responder).
Client discovery (lan::discover) and JVM/Keystore init via onAppStart are unchanged.
MainActivity drops init_service/start_capture/stop_service/check_service/stop_input/
notification/boot-option/sync_app_dir and floating-window start; voice uses AudioRecordHandle.
Old prefs (start-on-boot, floating window, accessibility grant) are inert after upgrade:
their components no longer exist. No Rust/wire/ABI/Windows change; native library reusable.
UI: no Share screen tab, no incoming chat tab, no LAN host settings tile on Android.
Merged-manifest permissions now INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE (normal,
no prompt, local interface enumeration for discovery; retained pending device proof) and
RECORD_AUDIO (requested at runtime only when the user starts a voice call). Removed with
tools:node="remove": MANAGE/READ/WRITE_EXTERNAL_STORAGE, POST_NOTIFICATIONS, battery-
optimization exemption, CHANGE_WIFI_MULTICAST_STATE (no MulticastLock in code; discovery
replies are unicast), FOREGROUND_SERVICE(+_MEDIA_PROJECTION), WAKE_LOCK (wakelock_plus uses
FLAG_KEEP_SCREEN_ON), RECEIVE_BOOT_COMPLETED, SYSTEM_ALERT_WINDOW; requestLegacyExternalStorage
removed. build85 APK manifest showed no plugin-contributed permissions.
Storage: Android file-manager local side is app-specific <external files>/Transfers (no
permission); "Add files from phone" and per-file "Save to phone" use the system picker
(file_picker 11.0.2, SAF). Save reads the whole file into memory (large-file limit).
Upgraders whose saved local_dir points outside it see an open error; Home recovers.
Automated: new flutter/test/android_outgoing_only_test.dart source guards. Here only a
Python port of those guards PASS and tree-sitter Dart/Kotlin/XML parse of all changed files
PASS (originals as control). flutter test/analyze, Gradle/Kotlin compile, merged-manifest
aapt check and APK build NOT run: no Flutter/Dart/Android SDK reachable from this session.
Next: full build with existing private signer and build number above 85 (versionCode >2085),
aapt badging permission check, flutter test, then AT-02 device acceptance (fresh install,
upgrade from 85 without clearing data, Windows->Android control attempts after upgrade/
restart/reboot must fail with no prompt or listener, mic prompt only on voice call).
Signing/Play Protect warning is a separate, unresolved issue.

2026-10-09 Windows-only sender selector correction86: Android1.3.7/logical85/internal2085
retained without rebuild/signature/permission changes. APK SHA256 rechecked exact
46C43D1BC6CB8D095EA1811AF5D118DC7E373D5D5FF71763FF2E94287CDC7737. Existing password/code/
manual wire reviewed against unchanged native85 on Windows86; no shared protocol/ABI or
Android receiver parity change. Flutter123 shared regression PASS, not paired-device
acceptance. Compatible public release1.3.7, Windows logical86 vs retained Android85.
Reported Android warning remains unresolved: existing helper uses Android Debug signing
certificate to preserve current upgrades; Windows UI fix does not certify APK safe or
remove Play Protect/install warnings. Exact warning screenshot still needed. No install,
signer migration, OS security/permission/mic or original-app data changes this task.


2026-10-09 FINAL matching Helper1.3.7/logical85/internal2085 APK and corresponding source
ready, not installed. APK46C43D1B...CDC7737, source1307BD29...6D4C2F989, snapshot3af9c05/
common29462e6. Full native7m06s/APK565.6s, helper signer43e19ba2...57c52/version/no-camera/
16KB/exact stripped native/English AOT wait key+oldArabicabsence PASS. Source private
gate1363 entries PASS/no signing material. Existing sender wire unchanged, no Android
receiver-default parity; Windows defaultON/persistent choice compiled and native tests
passed. Original2075/installed2084/data/mic not changed this turn. Paired actual85 manual
Accept/Deny/wait/code/saved reconnect/chat/buzzer/voice tests still pending. Both final
release1.3.7 deliverables/checksums/release+acceptance notes in outputs/SubnetDesk-helper-cm.

2026-10-09 Android85 build/staging gates COMPLETE: native7m06s/APK565.6s,
versionName1.3.7/internal2085/helperpackage/signature43e19ba2...57c52/no-camera/16KB/
exact stripped native match PASS. APK46C43D1B...CDC7737, nativeE6B9C856...6F5D449A.
Compiled Flutter AOT contains English waiting key, old forced Arabic prompt absent.
No APK installed; running2084/original2075/data/mic settings retained. Corresponding
source archives/final paired MSI delivery pending Windows build. Actual paired/manual/
saved reconnect/buzzer/voice acceptance is still open, not proved by compilation.

2026-10-09 user explicitly requests matching final APK/MSI: Android helper full native/
APK release1.3.7/logical85/versionCode2085 building fromc88c34f/common29462e6. Existing
sender/pending wire and English wait prompt retained, no Android receiver-default parity
added. Flutter110 PASS; final native/signature/no-camera/16KB/exact-library/source gates
pending. Preserve helper signer/original2075/data/mic permission; no APK installed this
turn. Actual manual wait/Accept/Deny/code reuse/saved reconnect/buzzer acceptance remains
separate and open. Earlier Android2084-no-new-build plan superseded by explicit start.

2026-10-09 manual-default change planned for Windows receiver only; Android2084 existing
request/pending wire reviewed for compatibility, no Android receiver parity or new APK
planned. Await explicit start; manual still OFF-by-default on current Windows84.

2026-10-09 reconciled84: full Android native6m27s/APK506.2s PASS, helper1.3.6/code2084
staged and install-r succeeded; signer43e19ba2...57c52/original2075/mic preserved. APK
BF505DE5...B948894/native08BAF073...0BD7CDC verified. Existing83 instrumentation driver
against actual updated release84 Keystore synthetic PASS, not paired JNI proof. Live
home/dropdown/manual explanation English/no Arabic in own UI nodes, password mode restored
without auth/request submission. AOT confirms old Arabic wait present83/absent84 and new
English key present84. Actual manual pending prompt, saved reconnect, code, buzz/voice/chat
paired acceptance open.84 corresponding-source archive remains unfinished.

2026-10-09 SubnetDesk CB execution approved/source9a9337b: user confirmed reported
Arabic is manual approval wait prompt. Replaced hardcoded shared message with
translate('Waiting for receiver approval (up to 60 seconds)'); Flutter UI-wide Arabic
source guard and English source-key regression PASS, full Flutter106 PASS. Existing
language selection and user-entered content preserved. Full helper1.3.6/code2084 native/
APK build running because Android message changed; existing2083/original2075 untouched
so far. Unchanged wire reviewed, no Android receiver parity inferred. Preserved signer/
helper-only upgrade and actual waiting-message acceptance still pending.

2026-10-09 SubnetDesk user selected reusable two-hour/restart receiver code; existing
Android2083 sender wire needs no new field/method. Review compatibility during approved
Windows implementation; no Android rebuild/receiver parity or new implementation now.

2026-10-09 SubnetDesk longer-code/audible-buzzer plan: existing Android2083 sender retained;
no new APK/code/receiver parity. User reports buzzer visually reaches laptop, audibility
apparently fails. Intended expiry/native sound changes target Windows receiver; review
unchanged wire with Android2083 and actual paired buzz/code after approved execution.
Single-use vs two-hour reusable code requires user choice; planning-only/no implementation.

2026-10-09 FINAL SubnetDesk83 Android binary/source checkpoint: installed Helper2083/
1.3.5 and foreground launch confirmed; source snapshot2787bf3/commonb56ada4 with private
gate1354 entries PASS, source ZIPB5426A75...019E07C8, APK1536BB6E...92811B9C.
Actual English home one Password field/no Username, three-method dropdown; code six-digit
field, manual explanation/no password, then normal password mode restored without auth/
request. Actual release-helper minimum3-byte Keystore synthetic PASS(testAPKBE260DDB...
64D1FBD4). Full build/signature/no-camera/16KB/exact-native and Flutter101 + native36
PASS; original2075/data/mic grant retained. Paired JNI save/restart/reconnect/forget/trust/
new-IP/code/manual/chat/voice/ring tests remain open; Windows runtime still82 needs human
close/security handling. No Android receiver parity or LAN Messenger implementation inferred.

2026-10-09 SubnetDesk83 Android full build PASS(native4m14s/APK351.7s), staged
1.3.5/code2083 and approved helper-only install-r PASS. Signer43e19ba2...57c52 preserved;
no-CAMERA/16KB/exact rebuilt native gates PASS. APK1536BB6E...92811B9C, strippednative
C55905CE...3966F0EF. Fresh Java test APK2m4s/minimum3-byte password-only payload tested
against actual installed release-helper: Keystore synthetic PASS(save/load, random nonce,
fingerprint swap/tamper/path rejection, forget), cleaned only own synthetic entries.
Original2075 and existing microphone grant preserved. Paired JNI save/reconnect/restart/
trust/code/manual/chat/ring acceptance pending. Corresponding83 source archive pending
Windows build/package; earlier in-progress notes below superseded for Android binaries only.

2026-10-09 separate SubnetDesk HOME-ACCESS execution approved: source85b9941/807f718
commonb56ada4 implements sender password-only UI/native validation and encrypted negotiated
wire3; remembered password keeps verified-fingerprint/Keystore gates, including empty
username payload and legacy-entry compatibility. New labels use selected-language translation
with English fallback. No Android receiver parity inferred. Flutter101/101 PASS, analyzer
no errors/60 legacy warning-info findings. Full native+APK1.3.5/code2083 in progress;
installed helper2082/original2075 unchanged. Minimum-payload Keystore device and paired
save/restart/forget/trust acceptance pending, not proved by Flutter/wire tests.

2026-10-09 SubnetDesk latest password-only plan adds HA-04b for Android sender/native
validation/verified-device Keystore and legacy compatibility. Remove username requirement
for new receiver flow, not merely hide the field or invent an account. No receiver parity
or Android implementation/build yet; language correction remains planned.

2026-10-09 separate SubnetDesk language correction planned, not executed: new access/
credential dropdown/remember/forget labels were hardcoded Arabic, violating selected language.
HOME-ACCESS plan HA-05 covers existing translation path/English fallback without changing
global preference. Android remains sender, no automatic receiver/unattended parity. No new build.

2026-10-08 FINAL separate SubnetDesk82: approved helper1.3.4/code2082 installed-r, original
1.3.0/code2075/data/mic grant preserved. Actual release-helper Keystore instrumentation
PASS: synthetic save/load, random nonce, fingerprint-binding swap rejection, ciphertext
tamper rejection, forget, invalid path; cleaned only own random synthetic entries. Initial
Kotlin test driver failed before tests on release-shrunk Function1; Java framework driver
f678dbd rebuilt1m16s/signature matched/isolated helper.test installed and PASS. Production
APK unchanged by test-only driver fix. Paired native JNI save/restart/forget/new-IP/trust/
code/manual/chat/ring acceptance still pending; no all-features acceptance claim. APK
41F6876C...5F2F414F, Android sourceA769DCA0...B95ABA0/private gate1352 entries PASS;
release82 notes/full SHA256SUMS in outputs/SubnetDesk-helper-cm. No LAN Messenger changes.

2026-10-08 separate SubnetDesk helper82: final ARM64 native4m18s, APK390.2s PASS; signed
com.zibochen.subnetdesk.helper1.3.4/code2082 with preserved43e19ba2...47057c52 signer,
no CAMERA,16KB alignment and rebuilt stripped library matching packaged31F4CB14...53F7096.
APK SHA25641F6876C7B91D4F47CF3C81C018DB1C071B9B4C9F0481E2AF243411C5F2F414F.
Approved install-r succeeded; original1.3.0/code2075 unchanged; user mic grant retained.
Instrumentation initially crashed before tests on missing Kotlin Function1 in shrunk release;
test-only framework Java driver f678dbd rebuilding; Keystore acceptance NOT yet claimed.
Native credentials4/4, access10/10, wire3/3, final Flutter96/96 PASS. Paired saved-password/
restart/forget/new-IP/trust/code/manual/chat/audio remain separate real acceptance gates.
No LAN Messenger application/signing/parity changes.

2026-10-08 LAN Messenger 3.0.9 final release: the trusted-call exception bug recorded below
(`acceptInternal`'s own `!settings.allowIncoming()` gate, fixed to check the trusted mask the same
way `onInvite` does) is confirmed fixed by the user's own real two-device retest — Lap, "Call as
trusted", rings through to this phone while it is in "Messages only", and the user confirmed it.
Final build: `android/build.ps1 -VersionName 3.0.9 -VersionCode 107` (no suffix — this is the real
release artifact, not a test candidate), all four ABIs, original development signer unchanged
(SHA-256 `7f4a0794…8d4161`), matching Windows' 3.0.9 by explicit user request. Output
`outputs/LanMessenger-3.0.9.apk`, 23,188,552 bytes (manifest
`outputs/SHA256SUMS-Android-3.0.9.txt`). The `-messages-only-test` 3.0.6/3.0.7/3.0.8 candidates
from this session's device troubleshooting are superseded and removed from `outputs/`. Not
installed over the test phone's 3.0.8 by this session (that phone already carries the fix, tested
there before this version bump); no other device install, release notes, or push.

2026-10-08 latest separate SubnetDesk: chat-onlyAPK80 build/signature/identity/no-camera/
alignment/native/source-private gates PASS, not installed. Keystore password source d422290,
hardening a9eea0f: payload4/4, Flutter89/89, ARM64 release and internal preflightAPK81 PASS
(code2081/signature/16KB/raw-strip-package verified); not installed, latest write-readback/
caret-preserving checkbox/account-history hardening needs final rebuild. Keystore device
instrumentation and paired save/restart/forget/trust/new-IP tests remain. Android method
selector/password/code/manual + encrypted capability negotiation/pending cancel now wired
in SOURCE, no optional credential save/forget on successful code/manual login. Policy7/7
and generated bridge PASS; compiler/Flutter/interop verification in progress. Original app,
helper signing/data and permissions untouched; physical chat/audio/access acceptance pending.
Not all requested work complete; no LAN Messenger Android code/parity changes. See plans.

2026-10-08 "Messages only" presence mode implemented (source only, not yet device-accepted):
the people-menu's "Go offline"/"Go online" button now opens a chooser (`setItems` AlertDialog,
`PeopleListView.showConnectionModePrompt`) instead of disconnecting immediately — "Offline
(everything)" is the unchanged existing `setConnection(false)` behavior, and the new "Messages
only" option stays Online while setting the existing `MessengerService.setAllowIncomingCalls
(false)`, which already rejected incoming calls end-to-end via `CallSettings`/`CallController`
but previously was only reachable from a separate, generic "Allow incoming calls" switch under a
"Calls" heading — that switch is now removed from the menu (superseded by the connection
button); its notification-permission caveat and settings-error text remain, now shown
unconditionally under the connection control. A contact with an explicit trusted-call grant
(auto-answer voice or video) is an exception and still rings through under this mode —
`CallController.onInvite` now computes the trusted-call mask before the `allowIncoming()` gate
(previously the gate ran first and blocked trusted contacts too) and only declines when both the
mode is on and the caller has no such grant. A non-trusted caller declined this way receives a
new `DECLINE` body field (`reason: messagesOnly`, via new `rejectMessagesOnly`) and a new
`CallProtocol.EndReason.MESSAGES_ONLY`, shown by `CallUi.endLabel`/`endHint` as "Messages only" /
"The other phone is in messages-only mode" — a deliberate, explicit exception to this file's
earlier "Declined never discloses preference" design, per the user's specific request that the
caller be told why. Going online directly from full Offline always resets to fully available
(clears any leftover Messages-only restriction); the mode itself persists across restart via
`CallSettings`' existing file, unchanged by this work. Full Offline is unaffected: no trusted
exception, same as before. `android/build.ps1`'s real pipeline ran against this source: WebRTC AAR
integration, `javac`/D8 compile, and APK packaging (native libs for all four ABIs) all completed
with no compile errors; the run only stopped at its last step, zipalign, because it refuses to
overwrite the already-existing `outputs/LanMessenger-3.0.0.apk` from a prior session — a build-
script safety guard, not a build or test failure, and this session did not pick a new version/
suffix to push past it since no package/release was requested. Not signed or installed this
session; see `windows/STATUS.md` for the matching Windows change (built and `tests/run.ps1`-tested
there) and `../PROJECT_STATUS.md`'s feature comparison. See `../PLAN-CALL-DO-NOT-DISTURB.md` for
the full task breakdown and open device-acceptance checklist.

2026-10-08 follow-up: user-requested test-candidate package built for device testing:
`android/build-voice.ps1 -VersionName 3.0.7 -VersionCode 105 -ApkSuffix "-messages-only-test"`,
all four ABIs, signed with the preserved original development key (`keytool -printcert` SHA-256
`7f4a0794…8d4161`, matching every prior 2.x/3.x candidate — upgrade-safe, no uninstall needed).
A first attempt used the script's default `-VersionCode 99`, which silently produced an APK
Android refused to install over the already-installed 3.0.5/code104 ("App not installed") because
99 is a lower versionCode than what was already on the phone — Android blocks that as a downgrade
regardless of matching signer. Rebuilt at code105 (one past the last-known installed candidate)
to fix it. Output `outputs/LanMessenger-3.0.7-messages-only-test.apk`, 23,188,552 bytes
(manifest `outputs/SHA256SUMS-Android-3.0.7-messages-only-test.txt`). Installed via `adb install -r`
onto the reachable test phone (SM-S908E, 192.168.1.51) after a manual sideload attempt failed with
"package appears invalid" (a corrupted transfer, not an APK defect — `adb install` confirmed the
same APK installs and verifies cleanly). UI-automation pass over the installed app confirmed the
connection-button chooser, both directions, work exactly as designed.

2026-10-08 real-device bug found and fixed: the trusted-call exception above did not survive
contact with a live call. Captured `LANCALL` logcat during the user's own retest (Lap calling
"ultra"/SM-S908E, which held a Trusted call access grant with Voice+Video auto-answer from
`ultra`'s own Masters list for Lap, confirmed live via Windows' Slave-tab CALLGRANTS query, "Call
as trusted" chosen on the caller side) showed `onInvite` correctly admitting the call to ring
(no "messages only" decline logged) and then, on the auto-answer attempt that same admission
triggers, immediately sending its own DECLINE and logging `ending call ...: LOCAL_DECLINE` /
`Trusted auto-answer unavailable: Incoming calls are turned off`. Root cause: `acceptInternal`
(shared by manual Accept and onInvite's trusted auto-answer call) had its own, separate, older
`!settings.allowIncoming()` gate that unconditionally declined — added before "Messages only"
existed, with no knowledge of the trusted-call exception onInvite now applies. Fixed by computing
the same trusted mask (`session.regularCall ? 0 : engine.trustedCallMask(session.peerId)`) there
too and only declining when it's zero, mirroring `onInvite` exactly. Windows has no equivalent
duplicate gate in `AcceptAsync` — confirmed by reading it — so this bug was Android-only.
Rebuilt/reinstalled as `3.0.8-messages-only-test`/code106 (`outputs/LanMessenger-3.0.8-messages-only-test.apk`,
manifest `outputs/SHA256SUMS-Android-3.0.8-messages-only-test.txt`), same original signer,
installed via `adb install -r` over 3.0.7 on the same test phone. Awaiting the user's retest to
confirm the trusted contact now actually rings through.

2026-10-08 SubnetDesk chat memory continuation: helper05a206d shared Flutter cleanup implemented
for outgoing Android session reset/error/reconnect/close/dispose and incoming CM lifecycle.
History/list references and selected draft discarded on session end; fold/tab alone preserves
active chat. Host Flutter89/89 PASS including16 memory/lifecycle tests. Windows frontend80
build passes; Android APK1.3.3/build80 candidate currently building, guarded reuse of verified
unchanged private native library (no Rust/protocol changes). Existing APK1.3.3/code2078 and
original Android app/data/signing/permissions untouched; no install or device chat acceptance.
Physical reconnect/network-loss/no-retained-draft checks remain pending. This is logical app
state removal, not a forensic RAM overwrite. Keystore saved-password option and three access
methods remain approved NOT implemented. See ../PLAN-SUBNETDESK-CHAT-MEMORY.md; no LAN changes.

2026-10-08 SubnetDesk new helper voice-start diagnosis (read-only): user reports Failed to
start voice call after Windows build79 switch. Resumed phone app is helper1.3.3/code2078,
PID16032. RECORD_AUDIO granted=false/AppOps ignore; filtered helper log at device clock
18:40:42 explicitly reports no RECORD_AUDIO permission, createAudioRecorder fail and
onVoiceCallStarted fail. Source correspondence verified; this recorded failure is missing
helper microphone permission. Original1.3.0/code2075 remains granted=true, but its separate
permission does not authorize helper. No permission/AppOps/install/source or signing changes;
user must handle helper microphone grant manually then retry. Windows79 phone transport/CM
is established, but audible voice/ringtone acceptance remains pending. No LAN/protocol edits.
See ../DIAGNOSIS-SUBNETDESK-VOICE-20261008.md; prior helper ungranted checkpoint still applies.


2026-10-08 latest separate SubnetDesk helper checkpoint: user explicitly approved View camera
removal on Android and Windows, retaining screen/control and voice. Shared/mobile controls
removed and native routes deny camera; source1.3.3+78, Flutter65/65 pass on Windows host.
Actual modified Android native Rust release PASS2m02s;115 compiler warnings recorded, no
Android-baseline warning comparison. ARM64/16KB LOAD alignment/JNI exports verified; newly
built/native-copy SHA2560656543e…eee1ec match. APK release PASS1164.2s, helper package/label/version
1.3.3/code2078/arm64/no CAMERA/v2 signature/16KB ZIP alignment verified; reproduced AGP strip
matches actual APK library B0e892cd…c4cdd36. Staged APK A36585e6…82341f. Source7a45b44 ZIP1330-entry
private gate PASS, SHA25602131885…c7cd7. Side-by-side install and activity startup441ms PASS;
helper process alive/no matching startup fatal/loader/Flutter errors in scoped snapshot.
Original1.3.0/code2075/update timestamp unchanged. Test signer43e19ba2…057c52 preserved privately,
never included in source ZIP; future build guard prevents silently changed signer. New helper
mic/notifications not granted; user handling. Paired UI/screen/control/voice/buzzer/camera-denial
acceptance still pending. Phone4KB pages; ELF/ZIP checks are not16KB device acceptance.
Scoped main native dependencies, libsodium and OpenSSL pass. Narrow host/target build fixes
committed in helper8a66332; pinned hwcodec build-only patch uses separate export, not Cargo
cache edits or default dependency changes. See ../PLAN-SUBNETDESK-ANDROID-BUILD.md. Scoped
physical dependency view avoids failed Rust library discovery through junction; regenerated
25.4MiB opus build cache. Candidate Gradle pins NDKr28c; no upstream old .so reused.
Original phone package/data and LAN Messenger signing remain untouched.
User reports voice now works after microphone grant; audible new ringtone/buzzer not accepted.
Android Keystore credentials/access modes approved, not implemented; no LAN Messenger edits.

2026-10-08 SubnetDesk private helper execution checkpoint: user approved permanent updater
shutdown and all listed buzzer/ringtone/access-mode work. Native updater policy and UI removal,
buzzer protocol/UI and Windows ring are implemented in helper source; focused Flutter17/17 and
first Windows Rust release pass. Final frontend/Android builds and physical acceptance pending;
running1.3.1 and original phone package remain unchanged. Three access modes/Android credential
store remain approved pending implementation. LAN Messenger source/parity/signing unchanged.

2026-10-08 user approved microphone permission and buzzer execution. RECORD_AUDIO now
granted=true/AppOps foreground; installed original app reconnected to Windows successfully.
Voice recording/listening retest pending. User approved separate side-by-side helper APK;
original app/data remain intact. Buzzer source work in progress, not built/accepted yet.
Three access modes are a new plan-only request: ../PLAN-SUBNETDESK-ACCESS-MODES.md; no auth
changes yet. Password storage is not silently bundled into buzzer work. LAN Messenger unchanged.

2026-10-08 separate SubnetDesk phone diagnostic: SM-S908E/Android16, installed
package com.zibochen.subnetdesk1.3.0/code2075 has RECORD_AUDIO granted=false/AppOps ignore.
At10:01:23 app log explicitly reports no RECORD_AUDIO permission then onVoiceCallStarted fail.
No permission change, new call, APK/install or app repair performed; enabling permission and
audible Android->Windows retest remain pending. See ../DIAGNOSIS-SUBNETDESK-VOICE-20261008.md.
Buzzer sender -> Windows receiver plan in ../PLAN-SUBNETDESK-CHAT-BUZZER.md awaits explicit
execution. Official SubnetDesk signer unavailable; candidate identity decision precedes APK.
Password saving remains plan-only. No persistent chat/buzz storage; LAN Messenger unchanged.

2026-10-07 separate SubnetDesk helper request (planning only): user requested a per-device
remember-password option in the Android version; interpreted as SubnetDesk, with that assumption
stated explicitly. Its v1.3.0 mobile UI hardcodes remember=false and its Rust credential store
supports desktop keyrings but rejects Android. A scoped opt-in, fingerprint-bound encrypted-store
plan with a forget action and device tests is in `../PLAN-SUBNETDESK-ANDROID-CREDENTIALS.md`.
No Android app changes/build/signing/install performed for this request; LAN Messenger unchanged.

2026-10-06 user-requested test-candidate package 3.0.5/code104, packaging the frame-validator fix
below: `android/build.ps1 -VersionName 3.0.5 -VersionCode 104`, all four ABIs. Original signer
confirmed unchanged (SHA-256 `7f4a0794…8d4161`) — upgrade-safe over 3.0.4 and earlier. Output
`outputs/LanMessenger-3.0.5.apk`, SHA-256 `d63460e9…a6ba6ad5f` (manifest
`outputs/SHA256SUMS-Android-3.0.5.txt`). Not installed on a device by this session.

2026-10-06 trusted/regular call frame-validator fix (source + shared test fixtures, not packaged
yet): the user's "Call normally" choice failed with "Refusing to send an invalid call frame" —
`CallVideoProtocol.java`'s/`CallVideoProtocol.cs`'s v2 INVITE validator checks the frame body's
key set for an EXACT match (`caller`,`callee`,`media`), so the new optional `trust` key made every
INVITE with it invalid on both send and receive. Fixed identically on both platforms: the INVITE
case now accepts the body with or without `trust` present, and when present requires it be
exactly `"ignore"`. Three new rows added to the shared
`tests/video-contract/fixtures/call-frames.txt` corpus (valid-with-trust, invalid-bad-value,
invalid-extra-key). Full `tests/video-contract/run.ps1` passes clean: 116 frame records, 38
capability records, zero Android/Windows diffs, including all three new rows behaving as
expected on both sides. Not yet packaged.

2026-10-06 user-requested test-candidate package 3.0.4/code103, packaging the trusted/regular
prompt bugfix below: `android/build.ps1 -VersionName 3.0.4 -VersionCode 103`, all four ABIs.
Original signer confirmed unchanged (SHA-256 `7f4a0794…8d4161`) — upgrade-safe over
3.0.3/3.0.2/3.0.1/3.0.0. Output `outputs/LanMessenger-3.0.4.apk`, SHA-256 `8b8e9456…271838fc55`
(manifest `outputs/SHA256SUMS-Android-3.0.4.txt`). Not installed on a device by this session.

2026-10-06 trusted/regular prompt bugfix (source only, not packaged yet): the 3.0.3 prompt never
appeared because `startCallTo()` checked `PeerEngine.trustedCallMask(peerId)`, which records
grants THIS device gave to OTHERS (the opposite direction) -- a device can never see its own
local grant table change based on what someone else granted it. Fixed by checking the grant the
OTHER device reports holding over this one instead: the same verified CALLGRANTS/1 query the
recipient-control UI already uses (`PeerEngine.remoteCallGrant`/`refreshRemoteCallGrant`), via a
new `checkTrustedGrantThenCall(peerId)` that refreshes the remote grant on a background thread
(a real network round trip) before deciding whether to prompt. Compiled clean. Not yet packaged
or device-tested -- this is exactly the bug the user reported from the 3.0.3 candidate ("it opened
the call direct, no prompt").

2026-10-06 user-requested test-candidate package 3.0.3/code102, packaging the per-call
trusted/regular choice below: `android/build.ps1 -VersionName 3.0.3 -VersionCode 102`, all four
ABIs. Original signer confirmed unchanged (SHA-256 `7f4a0794…8d4161`) — upgrade-safe over
3.0.2/3.0.1/3.0.0. Output `outputs/LanMessenger-3.0.3.apk`, SHA-256 `30c492be…4196190d` (manifest
`outputs/SHA256SUMS-Android-3.0.3.txt`). Not installed on a device by this session; this is the
feature that most needs a real paired call before acceptance (auto-answer suppression and
recipient-control suppression are both local reasoning, unverified end to end).

2026-10-06 per-call trusted/regular choice (source only, not packaged yet): a device holding a
trusted call grant over a contact (auto-answer and/or recipient camera/speaker control) now gets
asked, at call start only when such a grant actually applies, "Call as trusted" (pre-selected,
byte-identical to prior behavior) vs "Call normally" (this one call only -- the stored grant is
untouched). Wire change: the INVITE's existing free-form body gained an optional `"trust":
"ignore"` key, sent only for "Call normally"; omitted entirely for "Call as trusted", so the
common case is unchanged on the wire. `CallSession.java` gained `regularCall`; `CallController.java`
reads the key on receipt and skips its own trusted auto-answer path when set, and the recipient
camera/speaker command methods (`requestRemoteCamera`/`requestRemoteSpeaker`) now also refuse
when the local session is marked regularCall, alongside `MainActivity.java`'s
`recipientControlMask`/`refreshRecipientControls` gating. A v1/legacy peer or any build that
doesn't recognize the new key already ignores unknown body keys, same tolerance as the existing
`media` key -- no compatibility break. Compiled clean (javac over
`android/src/net/lanmsg/chat`, 0 errors). Not yet built into a signed candidate or device-tested;
no interop corpus update yet (see windows/STATUS.md for the matching Windows-side change — both
need a real paired call, both directions, both dialog choices, before this is accepted).

2026-10-06 user-requested test-candidate package 3.0.2/code101, packaging the call-controls
redesign below: `android/build.ps1 -VersionName 3.0.2 -VersionCode 101`, all four ABIs. Original
signer confirmed unchanged (SHA-256 `7f4a0794…8d4161`) — upgrade-safe over 3.0.1/3.0.0. Output
`outputs/LanMessenger-3.0.2.apk`, SHA-256 `e0359687…7c45f02` (manifest
`outputs/SHA256SUMS-Android-3.0.2.txt`). Not installed on a device by this session.

2026-10-06 call-controls follow-up (source only, not packaged yet): `CallView.java`'s
`videoControls()` was rewritten after real-use feedback that the control row's long text buttons
("Recipient speaker on", "Recipient front", etc.) were wrapping onto two lines. Replaced with
compact circular emoji icon buttons (reusing the existing `dotButton` helper, 48dp), organized
under two small section captions, "Your camera" and "Recipient controls": your camera on/off,
switch camera, show/hide preview, reset preview, diagnostics and fullscreen in the first row;
recipient speaker (🔊/🔈, one tap) and recipient camera (🎥/📷, one tap) plus a single
front/rear flip button (🔄, one tap, replacing the previous two separate always-visible
front/rear buttons) in the second, when the respective trusted grant is present. Every recipient
action is now a single tap, matching the request that no control need a second screen or a second
button to reach. Compiled clean (javac over `android/src/net/lanmsg/chat`, 0 errors). Not yet
built into a signed candidate or device-tested.

2026-10-06 user-requested test-candidate package 3.0.1/code100, packaging the UI/feature pass
below (fullscreen call video, Direct connections refresh, navy/blue restyle): `android/build.ps1
-VersionName 3.0.1 -VersionCode 100`, all four ABIs. Original signer confirmed byte-identical to
3.0.0 via `keytool -printcert` (SHA-256 `7f4a0794…8d4161`) and `apksigner verify` (v2/v3, one
signer) — upgrade-safe over the installed 3.0.0. Output `outputs/LanMessenger-3.0.1.apk`,
23,184,456 bytes, SHA-256 `9ffb1131…5fa0399` (manifest `outputs/SHA256SUMS-Android-3.0.1.txt`).
Not installed on a device by this session; no physical acceptance claim for the new features —
that's on the user to try.

2026-10-06 UI/feature pass (source only, not a release, not device-installed):
(1) Call screen fullscreen video: `CallView.java` gained a `fullscreenVideo` toggle, reachable
from a new "Fullscreen" button in `videoControls()` when a video call is Connected. Fullscreen
hides the header and the whole control stack so the remote picture fills the stage, leaving only
a small floating "Exit fullscreen" button and the hang-up disc on screen. Resets on call end,
same as the existing `collapsed` flag. No orientation-specific layout was added — only the
existing activity-level `configChanges` rotation handling applies.
(2) Direct connections IP refresh: the feature previously saved a peer's IP once and never
revisited it. `PeerEngine.java` gained `refreshDirectTarget(peerId)`, which re-probes the stored
address first, then (only on failure) sweeps the phone's current local /24 subnet(s) for a TLS
certificate matching the one already on file for that peer — never a different, unverified
device — and persists the new address on an exact match. No wire/frame change: reuses the
existing HELLO handshake and TLS fingerprint check. `DirectConnectionUi.java` gained a per-peer
"Refresh" button and an "Automatically refresh every 3 minutes" switch (persisted in the
`lan_messenger_connection` SharedPreferences); `MessengerService.java` runs the periodic sweep via
a self-rescheduling `Handler` loop (`directAutoRefresh`), gated on that switch and on Direct
connections being enabled.
(3) Classic/elegant restyle: `MainActivity.java`'s central `ink`/`accent`/`headerDark`/`chatBg`/
`bubbleMine`/`seenBlue`/`panelBg` constants and `CallView.java`'s `BAR`/`BAR_DIM`/`STAGE_COLOR`
moved from the WhatsApp-green palette to a navy-header/blue-accent palette (matching the Windows
restyle in the same pass). `button()` now builds a pill-shaped light-accent-tinted background
instead of plain platform button chrome; contexts that already override the background (menu
rows, inline voice-card buttons) are unaffected.
All three: compiled clean (javac over `android/src/net/lanmsg/chat`, bootclasspath/classpath
matching `build-voice.ps1`'s own invocation, 0 errors). Not run against a signed build, not
installed on a device, no physical acceptance — this is a source-only checkpoint per the
project's planning-first/execution-only-on-request split; packaging was not requested.

2026-10-06 user-authorized3.0.0/code99 release APK built with arm64-v8a, armeabi-v7a,
x86 and x86_64. Signature verified using original7f4a07943d01da1266e4f2d3ce757165c9619c9a4ef74e741c58f8eee08d4161;
manifest3.0.0/code99 confirmed, upgrade-safe over98. Output LanMessenger-3.0.0.apk;
not auto-installed in this release turn. Paired physical acceptance still incomplete.

2026-10-06 paired video test: phone-originated call negotiated video and its physical image
was rendered on Windows. Phone remote view was black, matching Windows local preview;
Windows camera content unresolved. Android Diagnostics displayed Unavailable. Clean remote
hangup; no Android source change, bidirectional image acceptance or release claim.

2026-10-06 paired continuation: with explicit user approval, Direct connections remains enabled
and now selects both ultra and Lap. Lap became Online. Android-originated voice call reached
Connected after Windows UI acceptance; OFFER/ANSWER and MEDIA_READY completed, then Windows
hangup was received cleanly. No camera started; audio listening/video acceptance remain pending.

## 2026-10-06 Windows-interoperability dev candidate installed (not a release)

Observed USB SM-A075F `R8YY80A8VLB` carried 2.2.69/code96. Built and installed original-key ARM64
`D:/LAN-Messenger/outputs/LanMessenger-2.2.71-wvc-completion-dev.apk` with versionCode98 using
`adb install -r`; installed version confirmed and firstInstallTime remained 2026-10-04 12:42:49.
Signer SHA-256 remains `7f4a07943d01da1266e4f2d3ce757165c9619c9a4ef74e741c58f8eee08d4161`.
This candidate includes the already-committed mirrored SAVP validator fix; no Android source was
changed during this continuation. Existing data/identity and Direct connections policy were preserved.
Physical Windows↔Android acceptance remains pending: the phone currently exposes ultra in Direct
connections, while Windows Lap sees SM-A075F Offline. No release, Wi-Fi repair or parity claim.


## 2026-10-06 mirrored SDP transport-profile relaxation (source only, not a release)

Android changed in exactly two places, both forced by the Windows call v2 regression repair documented
in `../windows/video-calling/TASK-CONTRACT-CALL-V2-FIX.md`, and neither is an Android behaviour change
on its own.

`CallVideoProtocol.validSdp` accepted only `UDP/TLS/RTP/SAVPF` as the m-line transport. libwebrtc
writes `SAVPF`, so Android was never the side that failed — but the two ports are contractually
required to reach the same verdict, and the shared corpus now proves it. `CallVideoProtocol.java` and
`windows/CallVideoProtocol.cs` both accept exactly `UDP/TLS/RTP/SAVP` and `UDP/TLS/RTP/SAVPF`, and both
still refuse `TCP/TLS/RTP/SAVP`, `TCP/TLS/RTP/SAVPF`, `UDP/TLS/RTP/SAVPX` and every other token. This
is a relaxation of what is accepted, not a new frame type: no Android-originated frame changed, and
`shared frame corpus : 113 records agree between Android and Windows` plus `38` capability records now
hold three ways against the hand-authored expectation.

`FakeCallMedia` emitted `SAVPF` in both its video and audio SDP. It now emits `SAVP`, matching what the
Windows adapter actually produces. This is deliberate: while the fake agreed with the validator by
construction, no test on either port ever fed the validator the SDP a real peer produces, which is
precisely why the mismatch shipped unnoticed and killed real calls with `EndReason.MediaError`.

All video-contract suites pass (DraftVideoContract 43/0, CallCameraPermission 18/0, CallVideoConsent
74/0, ConfirmedVideoContract 115/0, CallVideoActions 27/0, CallVideoResources 19/0, FakeCallVideo 18/0,
CallFrameAdmission 17/0, CallCapabilities 18/0, CallVideoCoordinator 39/0, CallVideoDiagnostics 13/0,
CallVideoPlacement 9/0). No APK was built or installed, no release, no version bump, no commit, no
push. Physical Windows↔Android call acceptance is still outstanding and nothing here claims it.

## Final release 2.2.70 / code97 — 2026-10-05

The user accepted the 2.2.69 installed candidate as stable and explicitly authorized final
release packaging with one documented limitation, without a camera-behaviour change. Final
all-ABI APK: `D:\LAN-Messenger\outputs\LanMessenger-2.2.70.apk`, 23,184,456 bytes, SHA-256
`c405937d61d6a398492210b33d4774788777cfd43ce7d767841e3d7a32783a88`. Package metadata is
`net.lanmsg.chat`, versionName `2.2.70`, versionCode `97`, minSdk 26, targetSdk 34. The APK
contains arm64-v8a, armeabi-v7a, x86 and x86_64 WebRTC libraries. APK Signature Scheme v2/v3
verification passes with one signer; signer SHA-256
`7f4a07943d01da1266e4f2d3ce757165c9619c9a4ef74e741c58f8eee08d4161` is identical to
2.2.69, preserving upgrade compatibility.

**Known camera limitation:** a trusted Slave device cannot start a new camera capture if the
Slave phone is already locked. If the call and camera are started while that phone is unlocked,
camera capture continues normally after the phone is locked. This release does not claim locked
new-camera startup and does not implement idle camera pre-arming.

Release verification against the exact build's compiled classes: CallCheck 440/0; real-TLS
permission list 40/0; recipient-control visibility 28/0; Direct connections 34/0; video consent
74/0; confirmed contract 115/0; shared frame fixtures 107/0; capability fixtures 38/0; remaining
focused video policy/resource/coordinator suites all pass. Production build, DEX, four-ABI
packaging, zipalign, signing and signature verification pass. Physical behaviour is accepted from
the installed 2.2.69 candidate; 2.2.70 changes version/package output only and was not reinstalled
in this packaging pass. Windows and the wire protocol are unchanged. No push was performed.

2026-10-04 background/locked calls checkpoint: authorized by "fix it all".
Trusted video now auto-accepts receive-only if camera acquisition is unavailable;
it no longer falls back to ringing solely because the Activity is backgrounded.
Notification actions are call-bound, asynchronous and logged; stale Accept cannot
decline a newer call. Incoming CallStyle belongs to the service FGS with redacted
lockscreen actions; default-importance new channel avoids forced heads-up;
active calls remove obsolete ringing notification. Already-prepared capture is
call-owned across Activity pause/lock. NEW camera preparation still requires
visible/unlocked app; idle trusted camera-service pre-arm is NOT implemented.
2.2.68 failed on Samsung standalone CallStyle posting and is superseded by corrected
original-key ARM64 2.2.69/code96 installed on both phones. APK SHA-256
5a85372b17e8590f8eb8403eb45a34111cc18bebed99f5b36b207bea67d2759f.
Call440/0, permission40/0, recipient28/0, direct34/0, consent74/0 and all video
contract/source-wiring/lifecycle checks pass. USB actual auto-accept/media readiness/
background heartbeat/remote hangup observed; complete locked-device notification
and camera acceptance remains pending. No all-scenarios or Wi-Fi repair claim.
USB first-install changed externally between observations; only install -r used,
no agent uninstall/clear or grant edits. Windows/wire unchanged. See
[locked-call diagnosis/implementation](../PLAN-ANDROID-LOCKED-CALLS.md).

2026-10-04 recipient-control visibility: implemented after explicit user "start".
Caller-side recipient controls now require fresh call-scoped confirmation of the
recipient's grant to this caller (Slave direction): camera scope4 shows camera
on/off/front/rear; speaker scope8 shows speaker only. Unknown/non-Slave/expired or
failed refresh hides controls. Active-call query refreshes every5s, confirmation
expires at10s; overlay rebuilds on scope changes and buttons recheck before send.
Last-known Slave list remains informational; recipient authorization unchanged.
Permission TLS40/0, presentation28/0, CallCheck422/0 and DirectConnections34/0.
Original-key ARM64 2.2.67/code94 test candidate built and upgraded on SM-A075F
USB R8YY80A8VLB and SM-S908E. APK `LanMessenger-2.2.67-slave-controls.apk`,
SHA-256 dec9705555ef96ee7ce741e6e322a1aa5ec550d64a2b47d171be74d214e07816.
Physical call-screen grant/revoke acceptance remains pending; known Wi-Fi fault
is unresolved. Windows and LM4 wire unchanged. See
[recipient-control plan](../PLAN-ANDROID-RECIPIENT-CONTROL-VISIBILITY.md).

2026-10-04: optional Direct connections implemented after explicit user execution
approval. Menu selects verified devices with editable IPv4:port. Engine disables
discovery, restricts TLS/fast sockets and incoming authenticated identities to
selected addresses/certificate pins, filters remote call SDP/ICE addresses, and
keeps other contacts offline with sends queued. Encrypted selection persists;
policy changes stop calls/sockets before restart, preserve actual Offline, and
malformed settings fail closed with explicit UI recovery. Deletion prunes targets.
Idle selected-peer TLS presence checks are paced to8s to retain compatibility
with existing peers'12s presence expiry; local direct presence expires at45s.
Direct34/0 real TLS/socket tests, CallCheck422/0, pacing28/0, permission36/0,
video-contract suites and service lifecycle guard pass. Signed ARM64 test candidate
2.2.66/code93 (`LanMessenger-2.2.66-direct.apk`) installed on USB SM-A075F
R8YY80A8VLB and SM-S908E, original certificate and first-install times retained.
APK SHA-256 b816dcea145b4a1fb9c54d0cbccad2eb18bf8b630a6242c0069c4bc2285b3ac5.
Device menu/native media/background acceptance and 10–15-minute Wi-Fi stability
test in enabled direct mode remain pending. No Wi-Fi repair claim. Windows and
LM4 wire unchanged; physical Windows direct-mode pairing pending. See
[direct-connections plan](../PLAN-ANDROID-DIRECT-CONNECTIONS.md).

Release decision 2026-10-03: user explicitly stopped investigation and requested
final packaging, commit and push despite the unresolved device-specific fault.
Android release 2.2.65/code92 packages current source for all four supported ABIs,
using the existing signing key. No additional device testing or settings changes.
Includes directional permission lists, trusted video and caller-side recipient
camera/speaker controls, plus idle delivery pacing and no Online multicast lock.
IMPORTANT: SM-A075F Wi-Fi loss remains unresolved; physical stability acceptance
failed. Packaging as a release does not imply this defect was fixed. Latest
automated evidence: CallCheck422/0, pacing28/0; earlier permission36/0 and
video-contract suites passed. Windows unchanged. Earlier release holds below
describe investigation history and are superseded only by this user decision.


Wi-Fi investigation execution checkpoint 2026-10-03: user authorized start.
Latest installed original-signer diagnostic candidate is 2.2.64/code91 on both
phones; full functionality restored, no traffic-suppression switches remain.
Uncommitted candidate removes Online multicast acquisition and paces idle TLS
delivery, avoiding idle probes to offline peers. It is NOT a confirmed repair:
SM-A075F dropped association at23:29:16.344,23:30:16.446,23:31:22.542 after
installation23:29:05. SM-S908E has not shown the corresponding problem; user
confirms the fault is device-specific. Wi-Fi remains enabled; no app crash found.
App-open Offline stayed associated23:04:07-23:07:12. Removing only multicast,
only delivery, or only outgoing discovery did not establish a stable fix;
discovery-only on both phones eventually dropped23:27:34.450. Suppressing all
scheduled traffic stayed associated for approximately186s, not ten-minute acceptance.
Current automated CallCheck422/0 and pacing28/0 pass; previous candidate permission
36/0 and video-contract pass. Device acceptance FAILED; release remains held.
Next isolation requires user choice for affected-phone reboot or another Wi-Fi
network. No router, Wi-Fi settings, app identity or original grants changed.


Wi-Fi repair planning checkpoint 2026-10-03: release held. Physical comparison
on SM-A075F: app force-stopped22:55:13-22:56:58 (~105s), no new disconnects;
reopened without a call22:57:02, disconnects22:57:35.264 and22:58:32.297.
Supports an app-related trigger, not a confirmed specific cause. App reopened,
original settings retained; no repair code applied. See
[Wi-Fi repair plan](../PLAN-ANDROID-WIFI-STABILITY.md).

CURRENT 2026-10-03: 2.2.57/code84 ARM64 original-signer TEST CANDIDATE installed
on both SM-A075F and SM-S908E. First-install dates/data retained. APK SHA-256:
022b54494cd62a9226f496defbe9dbc0d7cb704b4c852a0a0e27eec8b4621fcc.
Masters lists verified devices with local nonzero call grants, with edit/revoke.
Slave lists verified peers' authenticated grants to this device, read-only, with
conversation access. Optional CALLGRANTS/1 query exposes only requester's scopes.
Lists refresh every five seconds while open and have manual Refresh; session-only
remote cache has timestamps and offline/stale labeling. Unknown legacy/offline
peers are not falsely listed as granted. No capture or call starts from either list.
Implemented preceding changes: trusted initial video acceptance, separate remote
camera permission, caller-only recipient camera on/off/front/rear and speaker UI,
receiver-side role/grant checks, capture-readiness retry and terminated-worker
video detach guard. These are source claims, not complete device acceptance.
Automated: real TLS permission checks 36/0; CallCheck 422/0; all video-contract
suites pass (confirmed syntax 115/0). Production compile/DEX/package/v2-v3 signing pass.
Physical: A07 Masters showed S22/all four scopes; S22 Slave showed A07/same scopes.
Temporary S22 camera-only reverse grant showed S22 Masters/A07 Slave; revocation
removed both entries after refresh. Original grants restored (A07 grants 15, S22 0).
No AndroidRuntime error logged in this menu run. Offline/certificate mismatch
tested automatically, not physically in this run. Actual Windows interoperability
and complete recipient camera switching/speaker/lifecycle call acceptance remain
pending; earlier two-phone video frames rendered, later call ended on Wi-Fi loss.
NOT a final release. Historical checkpoints below are superseded where conflicting.

LATEST TRUSTED VIDEO/SPEAKER TEST CANDIDATE: 2.2.46/code73 ARM64 is built,
signed with the original certificate, and USB-upgraded without changing the
first-install time as `outputs/LanMessenger-2.2.46-trusted-dev.apk` (SHA-256
`9bbfbc54f7a0911cee72a397c767d31db649ab17804012f58a87ba4a7e405a06`). An
authenticated verified peer may now be granted automatic video-upgrade acceptance
and remote speaker routing separately. Automatic camera capture remains gated on
the app being visible, the device unlocked, camera permission, thermal readiness,
and the certificate-bound grant. CallCheck passes 422/0 and the production APK
pipeline/signature verification pass. A physical Android camera source initialized
successfully on SM-S908E through the isolated WebRTC feasibility harness. The
original reported end-to-end two-phone call has not yet been repeated on 2.2.46;
remote front/rear camera switching is not implemented and this is not a final
Android release.

LATEST TRUSTED-CALL/ICON SOURCE CANDIDATE: 2.2.45/code72 ARM64 built and signed
with the original certificate as `outputs/LanMessenger-2.2.45-trusted-dev.apk`
(SHA-256 `e801f62792e3916900cf27c61da880b8842596541a0bb82a5595d12cdd8bb07a`).
The supplied artwork is packaged as adaptive and legacy launcher icons. Verified
contacts have a certificate-bound **Trusted call access** setting; the implemented
scope automatically answers voice calls through the existing admission and accept
path. Revoke/remote forget, contact deletion and delete-all clear the grant.
CallCheck passes 422/0, including new grant persistence, ACCEPT-frame and revoke
tests; APK v2/v3 signature and icon resource resolution pass. Not installed or
device-accepted. Video auto-answer and remote camera/speaker control remain pending
the new shared control contract and device/background acceptance; this build does
not claim them and adds no control frame.

LATEST CLEANUP-FIX TEST CANDIDATE: 2.2.44/code71 ARM64 built and USB-upgraded
with original signer; first-install time unchanged. APK SHA256
e951d6aec05b5a65766fe84526288248e596b9293f7a11e93adf20baf50cc8fa.
Fixed demonstrated double disposal of receiver-owned video track, which blocked
later media initialization. Baseline failure reproduced; corrected actual native
adapter passed three camera/video lifetimes plus following voice-only setup and
cleanup. Pure video385/0, JVM native50/0, TLS8+19 and call417 pass. Full normal
regression ended exit1 at16-member reinvite capability refusal (FullMember10);
later tail not run.
Packaged two-phone acceptance remains pending; update BOTH Android endpoints.
No manual sound test repeated; Windows video still pending. Details and phases:
[cleanup repair handoff](video-calling/CLEANUP-FIX-HANDOFF.md).
Older snapshots below are historical, not active runner/release claims.

FINAL TEST-CANDIDATE RECORD:2.2.43/code70 arm64 APK rebuilt and reinstalled,
6349233 bytes, SHA256 4018ac369352602ba87005945b3166a59de971d0edbc858218b02d475f1f5855.
Original signer retained. Pure video385/0, native JVM41/0, TLS8/19 and voice-call
regression417/0 pass. Normal full regression ended exit1 at16-member group
reinvite capability refusal (FullMember6); later tail not run. Not a complete
accepted release; Windows video and packaged UI/lifecycle acceptance remain.
Current-source candidate details and historical intermediate hashes are in
A3-A4-CANDIDATE-HANDOFF.md. No full runner remains active.

Android 2.2.43/code70 arm64 TEST CANDIDATE is built and installed over2.2.42
on the USB phone with the original signer. Existing contacts/group/verification
remain visible and first-install time unchanged; Online startup works with
CAMERA denied. Production native video adapter physical-camera loopback/switch/
stop passed separately (151 physical/88 generated reverse decoded frames).
Pure video checks383/0, TLS capabilities8/0, call channels19/0; full regression
still running. Exact APK UI/video/clipboard/background acceptance remains open,
as do Windows R05 and cross-platform video. It is not a final accepted video
release. APK/hash and phase evidence: A3-A4-CANDIDATE-HANDOFF.md.

Android video candidate work continues: v2 coordination, native diagnostics,
shared-EGL render surfaces, preview placement/controls and camera FGS/lifecycle
are now in source. Pure video suites 375/0; physical UI/camera and exact-package
acceptance are not yet complete. Original-signer arm64 2.2.43/code70 candidate
build has begun; no new APK delivered or installed yet. Windows 2.2.42 stays
voice-only. See [candidate phase handoff](video-calling/A3-A4-CANDIDATE-HANDOFF.md).

In-progress continuation: opt-in v2 call/session integration and bounded video
coordinator added, with per-call CallVideoActions. Pure video checks 353/0;
actual TLS/fake-media call channel checks 19/0 and capability checks 8/0.
Service advertising remains disabled pending UI/FGS/lifecycle readiness.
No new production APK or physical-camera acceptance yet. See A07 handoff.

Latest A07 checkpoint (2026-10-03): fresh authenticated CALLCAPS probe/responder
boundary implemented, advertising remains disabled until v2 coordinator binding.
Call envelopes now reject foreign call/peer/version and replay before heartbeat;
CALLCONNECT cid and exact socket ownership survive handoff. Socket closure from
another rejected/busy call cannot end the current one. Actual TLS capability
checks 8/0 and authenticated call-channel/fake-media checks 8/0 passed. Call
regression expanded to 417/0; pure video/capability/admission groups 324/0.
See [A07 handoff](video-calling/A07-SIGNALING-HANDOFF.md). Remaining v2 video
session/media orchestration and UI/FGS/device/release gates are NOT complete.

Full A06 regression ended: all large-group/migration/ownership/transfer/Offline
tests passed; final Windows UI suite failed at Program.cs:315, socket error
10048 (port 43872 already held by user's Windows 2.2.42 app). App left running;
no unrelated code/port change. Full suite not PASS. Current-source targeted
Java/Windows secure peer and group/attachment integration passed afterward.

Latest Android A06 source checkpoint (2026-10-03): production separate secured
VP8 video adapter and explicit camera start/stop/switch implemented. Source is
not enabled through the controller/UI yet. Native adapter boundary fixtures
41/0 (JVM, no physical camera); fresh call checks 408/0 and video foundations
289/0. See [A06 handoff](video-calling/A06-MEDIA-HANDOFF.md). Actual device video,
A07 signaling binding and signed release acceptance remain pending.

2026-10-03 maintenance: user-approved cleanup of generated large transfer-test
payloads under outputs/.build/release-tests cleared the disk blocker (~76.9 GiB
free). No application/release/signing change; prior full-suite failure remains
recorded until rerun. A06 is the next authorized implementation task.

Latest source checkpoint: A04 consent/commands and A05 interface/service EGL/fake
video foundations implemented; actual video adapter/controller/UI still pending.
Fresh 48-source production compile passed. Resource/fake tests 19/18 passing.
DEX compilation passed; fresh call tests 408/0 and video-contract groups 289/0.
See [A05 handoff](video-calling/A2-RESOURCE-HANDOFF.md) for exact resume steps.
Full regression stopped during transfers because D: was full, not a full pass.
Older chronological checkpoints below do not override this current disposition.

Current user direction: audio testing accepted complete; do not repeat listening.
A02b selects VP8 on a separate secured video-only connection from actual paired
evidence. Shared exact wire/consent contract: video-calling/A02b-CONTRACT.md.
Android production video work resumes at A04; older listening caveats below are
historical and must not be used to reopen the accepted audio test.

Latest human listening result: no sound heard. Audible acceptance remains open;
passed packets/decoded samples are insufficient. No signed video release exists.

Latest 2026-10-03 paired feasibility: separate secured video-only connection
passed both original call/video-offer directions with generated moving VP8 and
continuing two-way G722. Video-off, video disposal and malformed video rejection
preserved audio. Production package/data unchanged. This is test-only evidence,
not a real video release; A02b contract and A04–A13 remain Pending. See
[paired evidence/handoff](../windows/video-calling/PAIRED-FEASIBILITY.md).
Older paragraphs below describe the earlier unpaired checkpoint.
End checks: fresh 44-source Java compile passed; existing call checks 408/0,
draft contract 43/0, camera permission helper 18/0. Full production regression
now passed Windows microphone tests 20/0 but failed full-group reinvite capability;
isolated group retry failed handshake/pairing. No unrelated group fix performed.
Windows production library migration is now explicitly authorized; its remaining
baseline, contract and packaging gates are documented separately.

## Video calling plan-v007 — Android execution started (2026-10-03)

The user authorized the Android section and phase handoffs, and requested USB adb.
The frozen plan hash was verified as
`4ea7877d6643b5c89246b075d7a301d73b38bea28f644303383fa42f7ca0efbf`.
Current execution record: [video handoff](video-calling/HANDOFF.md).
Latest continuation: Windows generated VP8 codec-local roundtrip passed (20/20
frames, 19 changes), not paired media. Android completion still has A04–A13 plus
A07d/A08m/A09d (13 implementation tasks), AT02–AT06 (5 test groups), AT01 post-gate
rerun and Both A02b. See [remaining checklist](video-calling/REMAINING.md).
No signed video candidate/release exists and no completion-time claim is made.
Latest dependency milestone: Windows replacement offline input packaged and
native/.NET ABI smoke passed with G722 present; real media pairing has not begun.
R02 endpoint construction, R03/R04 and A02b still Pending. Full regression rerun
again stopped at Windows recording device mmresult 1; no new Android acceptance.
Continuation: user accepted permissive transitive licenses without geographic
restrictions for the Windows replacement audit. Binary notice review and recent
advisory dispositions advanced; offline input/header packaging remains Pending.
No new Android media/device acceptance or A02b pass is implied.
A01 ownership/state design and A02 provisional contract are documented; initial
AT01 draft checks pass 43/43. AP01 is a separate test-only libwebrtc endpoint under
`tests/video-feasibility/android`, built/signed with a throwaway key and installed
through USB on SM-A075F (Android 16). Generated-frame native loopback passed VP8
re-offer, VP8 inactive activation, VP9 profile 0 and H264 constrained baseline,
with moving decoded frames and continuing two-way G722 before/during/after video.
These are Android-local results; physical-camera, audible and Windows pairing
acceptance remain Pending. A03 call-bound camera permission preparation is in
source; its 18 pure-Java boundary checks pass, with actual OS/UI acceptance Pending.
The shared A02b gate remains Pending until paired Windows WT01 evidence proves
encoded video and continuing G722 during upgrade. Production video, parity,
release version, and packaged acceptance are unchanged. A04 onward remains Pending;
no production video capability is advertised. Android production javac/D8 build
and 408 voice-call checks pass. Full regression stopped at 5 Windows recording
device failures (mmresult 1); supplementary runs reached repeated group-membership
and ownership-transfer Java startup timeouts. Details and final tail results
belong to the handoff. The independent Offline tail passed. Windows UI checks
passed through voice playback/seek, then stalled at recording and were stopped;
recording/lifecycle UI acceptance remains incomplete. Android continuation waits
for Windows WT01 and Both A02b, with A0/A1 phase notes saved in the handoff.

## Voice Messages implemented in source (Phase 1 / A01-A11, not a release)

Android Phase 1 of the shared Voice Messages feature (`plan-v003`, tracked at
[PLAN-VOICE-MESSAGES-ANDROID.md](../PLAN-VOICE-MESSAGES-ANDROID.md)): record, send, receive and
play short voice clips, reusing the existing encrypted Normal attachment store with a
`voice-<message-id>.lanvoice.wav` marker filename — no new LM4 wire frame, matching the Windows
implementation exactly (see [Windows status](../windows/STATUS.md)). Fixed format: RIFF/WAVE,
16 kHz mono 16-bit PCM, 640-byte/20 ms frames, max 300 s/9.6 MB. Picked up after another agent
(a concurrently running opencode/OAK session) spent several hours hardening the shared I01-I04
contract layer (`tests/voice_messages/check_contract.py`, `validation-contract.md`) but had not
yet written any Android production code.

`AudioRecord`/`AudioTrack` capture/playback (one dedicated thread per adapter blocking in
`read()`/`write()` — architecturally simpler than the Windows `winmm` P/Invoke adapters, which
need to guard against an OS-invoked native callback on an arbitrary thread; Android's model has
no such callback to race against); a durable, encrypted, capped (10-entry) draft registry with
startup reconciliation (including a real duplicate-Send bug found and fixed on **both**
platforms during the Android verification pass — see below); transactional Send; Candidate/
Fetching/Playable/Invalid/Unavailable receiver cards; one active inline player app-wide with
seven-step seeking (±10 s buttons) and no plaintext playback file; audio-focus handling (an
Android-specific addition beyond Windows' equivalent task, which has no system-wide audio
session model); voice folded into the existing automatic-media scheduler under the shared nine
fixed rules; accessibility coverage that in one respect **exceeds** the Windows implementation
(`setAccessibilityLiveRegion` proactively announces ticking labels to TalkBack — Windows'
equivalent task explicitly could not achieve this without a custom `AccessibleObject` subclass,
and accepted it as a documented limitation instead).

**A01-A11 (all 11 implementation tasks) are code-complete.** Build/verification: this sandboxed
environment has a real Android SDK (`android.jar`, `build-tools 35.0.0`, `d8`, and the existing
signing key), so every task was verified by running the actual `javac -source 8 -target 8` +
`d8` steps `android/build.ps1` uses directly against every production source file — real
compile+dex confidence throughout, not a blind port, the same rigor Windows only got once its
own build was unblocked mid-session. `android/build.ps1` itself was **not** run directly for
this work (its own known pre-existing issue — `$ErrorActionPreference='Stop'` aborting on
javac's benign deprecation note on stderr, documented further down this file — predates Voice
Messages and is unrelated to it); the equivalent javac/d8 steps were run manually instead, same
as every prior release's verification in this file already had to work around.

AT01 (`tests/VoiceMessagesCheck.java`, real production classes against the shared manifest) and
AT02 (`tests/voice_drafts_android.py`, 8 real crash-boundary scenarios including actual process
kills and on-disk corruption) both pass. AT04 is partial (`tests/voice_scheduler_android.py`,
real end-to-end automatic-download scheduling, plus a deterministic fairness-counter unit test)
— the scheduler's exact admission-ordering edge case is untested for the same black-box-timing-
fragility reason recorded on the Windows side. AT06 (architecture-boundary + canonical-fixture-
source checks, `tests/voice_architecture_check.py`, now covering both platforms in one script)
passes, and the **complete `tests/run.ps1` regression suite passed clean, zero regressions**
from any A01-A10 change. **AT03 and AT05 (permission/lifecycle edge cases needing real
`AudioRecord`/`AudioTrack` device behavior, and one-player-enforcement/export/accessibility UI
interaction tests) were not attempted** — Windows only got its equivalent WT03/WT05 coverage
because its sandboxed environment happened to expose a real `waveIn`/`waveOut` device; no
equivalent has been confirmed for Android's audio stack here, and Android's `android.jar` is a
compile-only stub that cannot actually execute real device code even where it links. **Manual
two-device acceptance on physical hardware is Pending, cannot be performed by an agent** —
same limitation already recorded throughout this file for every other Android feature.

This is **platform-local only; interoperability with the Windows Phase 2 work (developed
concurrently in this same repository) has not yet been verified** — that is Phase 3 of the
plan, not yet started.

## Offline controls (G1–G3) — built as 2.1.1 local APK

`PeerEngine.goOffline()` stops a reusable session while retaining identity, contacts, groups, local history, cached attachments, partial transfers and queued direct/group sends; `close()` remains terminal (G1). G2 moves sole engine ownership into a bindable service, reads a separate persisted default-Online request before startup (independent of people-list filters), and shares notification/people-menu transitions. Offline is a strict no-LAN boundary: no discovery/listening/connections, Refresh/Add by IP, verification, group capability queries or remote downloads. Refresh/Add by IP are disabled while Offline; verification explains that Online is required. An interrupted transfer retains progress for resume after reconnect; remote peers turn gray after approximately 12 seconds. Offline demotes the connected-device foreground service and releases the multicast lock; chats/profile/queued sends remain accessible while the Activity stays bound. Explicit Offline and engine-load/network-bind failures clear the started-service lifetime, so an actual-Offline service is bound-only and may be destroyed after unbind while the persisted Online request remains available for Retry online. Foreground and multicast lock are held only during networking. `START_NOT_STICKY` avoids OS-driven background restarts; Activity startup reads the persisted preference and requests Online explicitly when selected, otherwise only binds locally. Service/UI behavior has **not** been exercised on a device or emulator. No LM4 wire/compatibility change.

G3 automated check: fixed `goOffline()` for a unit test that intentionally exercises storage without starting the engine (executors are then absent). Cross-platform `tests/offline_lifecycle.py` checks accepted idle socket closure, Add-by-IP/refresh and remote-download gating, rejected discovery while Offline, delayed avatar sync, group capability refusal, Fast direct/ordinary direct/encrypted ordinary cache receiver interruption and Fast sender interruption, stable partial state, no premature completion marker, integrity and duplicate-free retry. `tests/android_service_lifecycle.py` guards the bound-only cleanup on engine-load failure, bind failure, and unbind while actual Offline. Android SDK compilation, APK packaging/signature verification, and Windows SDK 9 build passed after the final service-lifetime correction. Historical source-based physical checks passed on two Android devices for sender-side and receiver-side Offline transitions during transfer, Online resume, integrity, and duplicate avoidance. Historical source-based ADB checks confirmed no crash/ANR and no remaining Started service after removing the Offline Activity from Recents; reopening preserved local content and Online recovery succeeded. None of these device checks accepts the packaged 2.1.1 APK.

Prior Android releases: **2.2.2** (2026-09-29, versionCode 29, replayable voice messages, drag
seek bar, sender-sees-own-voice-as-player), **2.2.1** (2026-09-29, versionCode 28, Send/Save-
button scroll fix), **2.2.0** (2026-09-29, versionCode 27, the first release packaging the Voice
Messages Phase 1 work), **2.1.1** (2026-09-27, versionCode 26). See the
[platform comparison](../PROJECT_STATUS.md).

## Voice calls A00–A04 — real WebRTC media, validated on a physical device (2026-10-01)

The WebRTC AAR (`io.github.webrtc-sdk:android:150.7871.01`, Maven Central) is downloaded and cached
by `android/prepare-webrtc.ps1`, and `android/build-voice.ps1` is the single AAR-aware build
pipeline (javac + d8 + aapt + apksigner, native `.so` packaged under `lib/<abi>/`). The AAR is now a
**hard dependency**: `WebRtcCallMedia` uses direct `org.webrtc` imports, so there is no
build-without-WebRTC mode. `android/build.ps1` is a thin wrapper over `build-voice.ps1` that keeps
its signing-key contract and its refuse-to-overwrite guard. WebRTC added roughly 12 MB to the APK
(arm64-only build: 6 MB; all ABIs: ~47 MB).

Validated on a physical Samsung SM-S908E (Android 16 / SDK 36, arm64-v8a) over network ADB: the
native library loads, hardware AEC/NS is used, and a loopback self-test drove two real
peer connections through SDP offer/answer (Opus), ICE (5 + 3 host candidates), DTLS-SRTP and
bidirectional audio to `packetsLost=0`, plus mute — **SELFTEST PASS**. The self-test was an
`exported="true"` no-permission receiver, since removed from both source and manifest and kept
only as `state/on-device/CallSelfTest.java.txt`; it is not in the installed package.

Runtime testing found and fixed real defects that static review had missed: an SDP result-plumbing
bug after the reflection-to-typed rewrite, and — most importantly — `PeerConnection.Observer`
callbacks arriving on the WebRTC signaling thread, where any blocking listener work deadlocked the
media thread against the caller. Ten build-pipeline bugs were also fixed, including `continue`
inside `ForEach-Object` silently terminating `build-voice.ps1` with exit code 0, native libs
packaged with backslashes (unrecognised by Android's loader), `-VersionName`/`-VersionCode` never
reaching the manifest, and an aapt quirk that rejects a `-M` file not named exactly
`AndroidManifest.xml`. See `state/handoff-A04-device.md`.

`tests/CallCheck.java` passes **142/142**; 37 production files compile clean against the AAR. The
device APK is `outputs/LanMessenger-2.2.7.apk` (versionCode 34), installed over 2.2.6 / 33. **No
real two-party call has been made** — a loopback proves the media stack but not the LAN signalling
path, and the Windows peer does not exist yet. Audio was never listened to, and A07 route
application, A05 arbitration under a live call, and runtime microphone foreground-service
behaviour all remain unverified on device.

## Voice calls A08–A10 — call UI, notifications, entry point (2026-10-01)

A call can now be placed and answered. The subsystem existed but had no way in: no entry point, and
a rejected invitation told the caller nothing. Phase A08–A10 closes that and four holes found while
wiring it.

**Entry point (A08).** `chatMenu` offers **Call** for a direct contact only — group calls are out of
scope, so a group row never shows it. `startCallTo` gates in the order a user can act on (not
online → unverified → offline → microphone permission) and every refusal is a specific message. The
permission is requested before the invitation and the pending peer ID survives the grant, so the
call is placed exactly once. The channel is opened on a background thread. `CallController.TransportFactory`
makes the controller mint the call ID and open the matching socket *inside its own lock*, so an
INVITE can never precede the connection carrying it. Turning "Allow incoming calls" off during a
ring **declines that call immediately** rather than letting it ring out its timeout.

**In-call UI (A09).** `CallView` overlays the Activity's `stage`, so it covers the people list and
the chat alike; the duration clock rides the existing 1 s `tick`. State, duration, mute, route and
quality are separate lines, a quality hint appears only for `Reduced` and is announced once, and a
terminal banner lingers 2500 ms. Back closes the overlay and falls back to a **return-to-call bar**
on the people screen — a call is not tied to a conversation, so leaving the chat must not hide the
only controls for ending it; Back never hangs up by accident. `CallUi` is service-owned and retains
the terminal snapshot so "Declined" survives the controller's return to Idle. `CallController` gained
`addListener`/`removeListener`, so the Activity and the service's notification both observe the state
stream without displacing the single callback slot, and a throwing listener is isolated.

**Notifications (A10).** Two channels: `calls_ringing` (HIGH) and `calls_active` (LOW, silent);
only the ringing channel may alert. Accept/Decline are explicit service intents carrying the call ID,
and **Accept opens `MainActivity`** rather than accepting in the background, because accepting means
granting a visible permission flow. `accept(expectedCallId)` re-checks the call ID *and* the live
preference, so a stale notification action cannot accept a replaced call or bypass a withdrawal.
"Allow incoming calls" lives in the people side menu, bound to the service's persisted setting, and
states that turning it off does not stop outgoing calls.

**Bugs found and fixed.** The incoming INVITE was being dropped entirely (`onFrame` returned early
on a null session and nothing called `onInvite`). A policy decline sent nothing, so the caller rang
out 30 s and reported "No answer" — now `DECLINE`, with `BUSY` for throttling and occupancy and
still silence for identity failure. `sendFrame` counted an outbound write as inbound evidence, so a
dead channel never tripped the liveness check. And `onInvite` never validated the call ID: a
non-UUID would create a session whose own frames the peer's parser rejects, so such a call could only
ever expire.

`tests/CallCheck.java` passes **229/229** (was 142). **Release is `outputs/LanMessenger-2.2.9.apk`**
(versionCode 36), 6,283,697 bytes, SHA-256 `2f8a12ad…b15a517d`, signed and verified (v2 + v3) and
installed over 2.2.8 (which confirms the same signing key). Release notes and
`SHA256SUMS-Android-2.2.9.txt` written. Verified on
device: no FATAL; WebRTC native stack OK (hwAEC/hwNS); both call notification channels created
(`calls_ringing` importance 4, `calls_active` importance 2); the **"Allow incoming calls" switch
toggles and persists across `force-stop` + restart**; the **Call action appears** in a verified
direct peer's menu; tapping it on an offline peer produced the correct `"Lap is offline."` and no
notification. See `state/handoff-A08-A10.md`.

**Still unverified, and it is the important part: a real two-party call has never been placed.**
Only one Android device exists (`192.168.1.4:5555`); there is no emulator (`emulator.exe` absent,
no AVDs, no nested virt) and the Windows peer has no call support. So the INVITE/RINGING exchange,
the overlay mid-call, notification actions in flight, network mute round-trip and the terminal
banner are covered by unit test and compilation, not by a live call. Speaker output is unverifiable
by adb, Bluetooth/wired route precedence is deliberately not claimed, and A07p proximity blanking,
A06 runtime microphone FGS promotion and A05 arbitration under a live call remain untested.

Also fixed while releasing: the About screen read its version from a hardcoded literal that had gone
stale (it showed 2.2.6 in a 2.2.8 build). It now reads `versionName` from the installed package, so
the manifest is the only place a version is declared and the two cannot drift.

Note: `outputs/LanMessenger-2.2.6.apk` was destroyed by an earlier build; `build-voice.ps1` now
refuses to overwrite a release artifact, which is why the release numbers stepped 2.2.6 → 2.2.7 →
2.2.8 → 2.2.9 rather than being rebuilt in place. `2.2.6-voice-dev.apk` survives as the voice build
of that version. **2.2.6 was not rebuilt**; 2.2.9 supersedes it.

Reviewed 2026-09-29. Current Android local APK build: **2.2.2**, versionCode 29 — a same-day
follow-up addressing real device-testing feedback on 2.2.1's voice messages, all in
`VoicePlayer.java`/`VoicePlayback.java`/`VoiceCard.java`/`VoiceUi.java`/`MainActivity.java`:
1) `VoicePlayer.resume()` was missing the end-of-track position reset that `play()` already had,
so pressing Play again on a finished voice message did nothing — `togglePlayback` always calls
`resume()` for the same active key, so a completed clip could never actually be replayed. Fixed
by mirroring `play()`'s `if (playPosition >= dataEnd()) { playPosition = info.dataOffset;
epoch++; }` reset in `resume()` too, so a voice message can now be replayed any number of times.
2) The fixed ±10s buttons are replaced with a draggable WhatsApp-style seek bar
(`VoicePlayback.buildSeekBar`/`updateSeekBar`), wired to `VoicePlayer.seek(long)`'s existing
absolute-position API, in both the received-message Playable card and the own-draft preview row.
3) The sender's own sent voice message now renders as a proper voice-message player (duration,
Play/Pause, seek bar, Save) instead of a generic file entry — `MainActivity.java`'s render() gate
no longer excludes `mine` messages from `VoiceCard.addVoiceCard`; this reverses the earlier
Phase-1 design decision documented in `VoiceCard.java`'s A07 comment and mirrored on Windows in
`ChatWindowVoiceCard.cs`'s W07 comment, per explicit user feedback that it should match WhatsApp
instead. `outputs/LanMessenger-2.2.2.apk` (131,415 bytes), SHA-256
`36f066f30d906bf13b65bdd98c42606a1af33d5619823b894241346f5e221fe5` (manifest:
`outputs/SHA256SUMS-Android-2.2.2.txt`). Signed with the original development key — confirmed
byte-identical signer certificate (`keytool -printcert`, SHA-256
`7F:4A:07:94:3D:01:DA:12:66:E4:F2:D3:CE:75:71:65:C9:61:9C:9A:4E:F7:4E:74:1C:58:F8:EE:E0:8D:41:61`)
to 2.2.1/2.2.0/2.1.1, so an existing install upgrades cleanly without uninstalling. `apksigner
verify` confirms v2/v3 with one signer. Built the same way as 2.2.0/2.2.1: `android/build.ps1`'s
exact pipeline run manually, command by command, rather than the script itself — its own known
pre-existing issue (`$ErrorActionPreference='Stop'` aborting on javac's benign deprecation note
on stderr, noted further down this file) predates Voice Messages and is unrelated to it; every
tool, path and signing input was still the project's own, and `android/build.ps1` itself was
not modified. Verified: real-toolchain `javac`/`d8` compile clean; no device/emulator acceptance
has been performed yet for this specific build — the fixes directly target the three issues the
user reported from real-device testing of 2.2.1, but that testing itself is still outstanding.

The Windows implementation still deliberately does *not* render the sender's own sent voice
message as a player (`ChatWindowVoiceCard.cs`'s W07 comment) and still only offers ±10s seek
steps (`ChatWindowVoicePlayback.cs`'s W08 comment) — this pass was Android-only, addressing the
user's Android device testing; Windows parity for these three UX points has not been raised with
the user and is not yet planned.

**Post-release icon pass (2026-09-29, same day)**: user feedback after 2.2.2 asked for WhatsApp-
style iconography — a triangle Play button and a microphone icon for the record trigger, instead
of text labels. Changed all voice transport buttons from text to Unicode glyphs: `▶`/`⏸`
(`VoicePlayback.PLAY_ICON`/`PAUSE_ICON`, used by both `VoiceCard.java`'s Playable row and
`VoiceUi.java`'s draft preview), `⏹` for Stop-recording, and `🎤` for the compose row's
"Record voice" trigger in `MainActivity.java` (content description text is unchanged for
accessibility — only the visible label changed). No layout, wire, or storage change. Verified
through the real Android toolchain (`javac -source 8 -target 8` + `d8`), 0 errors. Packaged as
**Android 2.2.3** (versionCode 30). Same signer as every prior release. No device/emulator
acceptance yet for this build.

**Second replay-bug fix (2026-09-29, same day)**: after actually installing and testing 2.2.3 on
a real device, the user confirmed the UI correctly detects completion (the button does flip back
to `▶`) but tapping it again still produces no audio — so the 2.2.2 `VoicePlayer.resume()`
position-reset fix alone was not sufficient. Root cause: a plain `AudioTrack.play()` call after
the track naturally drained (buffer underrun, never explicitly `stop()`ped) does not reliably
resume producing audio on every device — this is a known `AudioTrack` streaming-mode quirk, only
observable on real hardware, not from source review. Fixed by having `resume()` call
`track.stop()`+`track.flush()` before `track.play()` whenever it's restarting from the end (the
same clean-reset pattern `seek()` already used for its own pause+flush). Verified through the
real Android toolchain, 0 errors. Packaged as **Android 2.2.4** (versionCode 31), same signer as
every prior release. Still no device/emulator acceptance recorded here for this specific build —
depends on the user re-testing on the same device that surfaced the underlying quirk.

**Third replay-bug fix (race condition in the second fix, 2026-09-29, same day)**: the user
tested 2.2.4 and reported a new symptom — pressing Play now starts audio and then "stops
immediately", rather than the earlier silent no-op. Root cause: `resume()`'s `stop()`+`flush()`+
`play()` sequence ran *outside* the `synchronized(lock)` block, after `notifyAll()` had already
woken the write thread. The write thread could race ahead — write a fresh chunk into the track —
before (or while) `flush()` ran on another thread, wiping out (or racing against) that write; the
audible result is exactly "plays a fragment, then goes silent." Fixed by moving the entire
`stop()`/`flush()`/`play()` reset sequence *inside* the synchronized block, strictly before
`notifyAll()`, so the write thread can only ever wake up after the track has already been reset
and is already in the PLAYING state — eliminating the race rather than just narrowing it.
Verified through the real Android toolchain, 0 errors. Packaged as **Android 2.2.5**
(versionCode 32), same signer as every prior release. Still awaiting the user's re-test.

**Fifth pass — stop reusing the drained AudioTrack at all (2026-09-29, same day)**: the user
tested 2.2.5 and reported the same failure ("it play once... why i need to leave conversation to
play rec again"). Three straight attempts at reusing the same `AudioTrack` past natural
completion (position reset alone, then `stop()`+`flush()` outside the lock, then the same reset
correctly ordered inside the lock) all failed on this device — strong evidence this specific
`AudioTrack` cannot be reliably revived after it drains, at least on this hardware/OS combo,
regardless of how carefully the reset is sequenced. The one thing that *always* worked was
leaving the conversation and coming back, because that path throws away the old player entirely
and builds a brand-new `VoicePlayer`/`AudioTrack` from scratch. So instead of continuing to fight
the reuse case, `VoicePlayer` now exposes `isFinished()` (`!playing && playPosition >= dataEnd()`)
and `VoicePlayback.togglePlayback` checks it: a finished player is never resumed in place — it
falls through to the same "different key" branch that already builds a fresh player, i.e. tapping
Play again on a finished voice message now does in-app exactly what leaving and re-entering used
to do, with no navigation needed. `resume()` itself is back to a plain pause/resume toggle (no
`dataEnd()`/track reset left in it — that responsibility moved to the caller). Verified through
the real Android toolchain, 0 errors. Packaged as **Android 2.2.6** (versionCode 33), same signer
as every prior release. Still awaiting the user's re-test, but this is the first fix in this
chain built on a mechanism (fresh player construction) already independently confirmed to work
on the user's own device, rather than on a new theory about the failure.

## Voice calls A09 — call screen rebuilt to the Messenger reference layout (2026-10-02, 2.2.30)

The user supplied a reference call screen and asked for the app's call screen to look like it. It
did not: every label was stacked and centred in one dark slab with wide full-width text buttons,
there was no picture of who was being called, the toggles were crowded to one side, and ending the
call was a rectangle in a stack rather than a single unmistakable target. `CallView.build` is now
the reference layout: a dark teal header (`BAR` = `#0E524C`) carrying the peer's name as an
uppercase headline with the timer or status line under it and a 🔽 minimise control at its right;
the peer's synced picture (`avatarView`, falling back to the same coloured initial disc the people
list uses) in the window between; one large red `hangupCircle` disc — a 📞 rotated 135° inside a red
circle, because there is no hang-up emoji and 📴 reads as *phone switched off* — floating just above
a teal `controlBar` holding 💬 / 🔈|🔊 / 🎤|🔇 in three weight-1 slots. Ring screens use the same
frame with worded **Accept**/**Decline** and **Cancel**, and the minimised bar is the same teal.
The 💬 control opens that peer's conversation and leaves the call running; the Activity's
`Return / End` call bar keeps the call visible from there.

**Four defects the on-device acceptance run found, all of which had been live before this work:**

1. **The floating hang-up disc covered Accept and Decline while ringing.** It was floated at the
   same offset over the action zone in every state, so it sat on top of both buttons — tapping
   **Accept** hung the ringing call up instead of answering it (`LOCAL_HANGUP (was
   IncomingRinging)` in `LANCALL`). It is now added only for a non-ringing state; there is also
   nothing for it to mean while ringing, since Decline and Cancel already stop a ringing call.
2. **A minimised call could not be reopened.** Tapping the bar set `collapsed = false` and
   re-rendered, but `render()` compares call ID, state, mute and route against what the overlay was
   built for, and the bar matched all of them, so it decided there was nothing to rebuild and the
   bar stayed exactly where it was — a running call with no way back into it. It now hides and
   re-renders (`hide` then `render`).
3. **Back abandoned a live call.** `onBackPressed` called `CallView.hide()` while the call was still
   running, leaving the only full-screen indication that a call existed gone; the chat screen that
   remained looks exactly like the call had ended. Back now toggles — expand a minimised call,
   minimise a full one — via `CallView.backWhileLive`. A call deliberately off screen (opened with
   💬) is left alone so Back still navigates.
4. **The call clock started when the call was created, not when it was answered.**
   `CallSession.elapsedMs()` added `now - createdAtMs` to the connected duration, so a call picked
   up four seconds after ringing already showed `0:04`. It now measures from `connectedAtMs`, and
   the stored duration is only a floor for a snapshot taken before the connect time was set.

**Wording.** `SIGNALING_LOST` said **"Connection lost"**, which the user asked what it meant: it is
the signalling TCP pipe dying without either side hanging up — the far phone's app killed or
crashed, or it dropped off Wi-Fi — but the wording reads as *your* connection failing and gives no
way to act. It is now **"Disconnected"**, and `CallUi.endHint` gives **every** end reason a plain
sentence beneath the label (e.g. *"Lost the link to the other phone. Its app closed, or it went off
Wi-Fi."*), because a label alone could not distinguish the cases. Also fixed: the `Return / End`
bar is rebuilt when its words change and not only when it appears, so it no longer reads "Incoming
call" beside a running timer.

**Verification.** `tests/CallCheck.java` **PASS=352 FAIL=0** (50 new checks: `N143`–`N153` for the
answer-time clock and the end-reason sentences). Layout is presentation-only and cannot be asserted
from pure-Java tests, so acceptance is a two-device driver
(`outputs/.build/accept-layout.ps1`) that places a real call from SM-A075F to SM-ultraaysar and
asserts the hierarchy: all four regions present, bar order and spacing, the picture above the disc
and the disc above the bar, no wide `Hang up`/`Minimize` button surviving, toggles flipping glyph
and accessibility label, minimise/restore/Back (`M1`–`M8`), chat-without-ending, and the end reason
plus its sentence persisting. Packaged as **Android 2.2.30** (versionCode 57), same signer as every
prior release. Live audio quality, proximity routing and microphone foreground promotion are still
**not** assessed on device.

**Defects found after the redesign, one of them reported by the user afterwards.**

5. **The call screen passed every tap it did not use to the conversation behind it.** `attach()`
   adds the overlay to the stage at `-1,-1`, but a background colour does not make a view swallow
   touches and `FrameLayout.onTouchEvent` returns `false`, so anything that missed a child — the
   wall around the picture, the header padding, the gaps beside the disc — went back to `stage` and
   from there to the chat underneath. Tapping beside the avatar opened the conversation behind the
   call. The full-screen panel's holder is now clickable; `buildCollapsed` and `buildTerminal`
   deliberately are not, because the chat is meant to stay usable under those two.
6. **💬 did nothing.** It called `hide()` then `showChat()`, which ends in `render()`, which rebuilt
   the full-screen panel over the chat in the same tap. `CallView.dismissedCallId` now records the
   request, keyed by call ID so it lapses when that call ends or a new one starts.
7. **The `Return / End` bar froze at `0:00`.** Its rebuild key was `call.state`, an enum that stops
   changing at `Connected`, while the text beside it is a duration that changes every second — so it
   was built once and never refreshed. Now keyed on the words it actually renders.
8. **`LOCAL_DECLINE` told the decliner that the *other* phone declined.** It is produced only on the
   phone that pressed Decline, so the sentence was the wrong way round. **`SIGNALING_LOST`** named
   the other phone, but it is raised by heartbeat timeout, a local send failure and a local channel
   close alike — all of which happen when *this* phone drops — which sent users with dead Wi-Fi to
   check the far end. Both are side-correct or side-neutral now (`N152`, `N154`, `N155`).

`CallCheck` **PASS=354 FAIL=0**. The two-device acceptance run has **not** produced a valid result
since these fixes: the last attempt failed its online gate on both phones before any call was
placed. See [HANDOFF.md](../HANDOFF.md) for what is still open — chiefly the per-second TalkBack
announcement of the duration clock, which is a regression this work introduced.

## Second pass on the same work (2026-10-02, 2.2.31)

**"Group members" was offered on a direct conversation.** `chatMenu` added it unconditionally, so
opening the ⋮ menu on a one-to-one chat listed an item that could not work: `showMembers` looks for
a group whose id matches the open conversation, finds none, and falls through to a toast telling
the user the obvious. It is now guarded on the open conversation actually being a group. The menu
dispatch also used to end in `else showMembers()`, so **any** title not matched above it silently
opened the members dialog — adding one item meant forgetting to route it, and the wrong dialog
appeared instead of nothing. Every title is now routed explicitly. Verified on a device: a direct
chat offers Call / Verify device / Clear conversation, a group offers Group members / Clear
conversation / Leave group and no Call.

**TalkBack read the clock out loud once a second.** The status line carries the duration and was a
permanently-live accessibility region, so a screen-reader user heard "0:04", "0:05", "0:06" for the
whole call — the one thing that stops them hearing the person they are on a call with. The clock is
still *shown* every second; it is the announcement that is now gated to state transitions
(`CallUi.isNewStateAnnouncement`).

**The return-to-call bar rebuilt three views every second.** Keying on the rendered words fixed the
frozen `0:00`, but the words include the duration, so every tick of the clock did a `removeAllViews`
plus three new Buttons and four LayoutParams on the UI thread for the length of a call. The summary
is now built once and retargeted in place; the bar still rebuilds its buttons when the peer changes.

**Smaller items.** The hang-up disc's accessibility label was overwritten with a bare "Hang up",
so the specific "End the call with *name*" never reached a screen reader. `isCollapsed()` was dead
code and is gone. `N147` asserted an exact `"0:03"` against a value recomputed from the wall clock,
so it passed only inside a one-second window — it now accepts `0:03` or `0:04`, and a new `N146`
places the reported bug directly: a call that rang 20 seconds and was answered must read 0:00, not
0:20.

**Coverage.** The three decisions above — when to announce, when to keep the call screen dismissed,
and what the return-to-call bar shows — were moved out of `CallView` and `MainActivity` into
`CallUi`, because the pure-Java harness cannot load either class (`NoClassDefFoundError:
android/content/Context`), which is why they had no coverage at all. `N156`–`N166` now pin them.

`CallCheck` **PASS=370 FAIL=0**. **2.2.31** (versionCode 58) installed on SM-ultraaysar only.

**Not verified on device: the tap-through fix.** The other phone (192.168.1.44) is off the network —
100% packet loss — so no call could be placed from ultra and the call overlay never appeared.
`startCallTo` refuses an offline peer before creating a call, so this is not something to work
around. The fix is one line (`holder.setClickable(true)`) and two independent analyses agree on both
the mechanism and the fix, but it has not been exercised on hardware.

2.0.0's headline change was group membership no longer being fixed after creation (see below). It also still carries everything packaged in 0.8.12: the people-screen side menu and the `Show offline users` filter; Delete conversation / Delete app data (mirrors Windows); and a contact-forget notice plus group-leave + owner re-invite (mirrors the same Windows addition — see [Windows status](../windows/STATUS.md)). 2.0.0 briefly also shipped a join-request feature; 2.0.1 removed it. **2.1.0's headline change is group ownership transfer** — see below.

## Implemented

- **2.0.0** (foundation, still current): group membership is no longer fixed after creation — mirrors the Windows foundation exactly (see [Windows status](../windows/STATUS.md) for the full design). `Group.members` is now the live active roster with a `membersVersion` counter, propagated to every active member as a full snapshot (new `LM4\tMEMBERSUPDATE`/`MEMBERSUPDATEACK` frame in `PeerEngine.java`/`GroupSync.java`) adopted whenever strictly newer. `GROUP` invites stay 6 fields while a group's version is 0 and switch to 7 (with the version) once mutated; the dispatch (`m.length==6||m.length==7`) accepts either. Any owner-initiated growth (`GroupSync.addMember`, used by `reinviteMember`) requires a fresh `LM4\tCAPS` query (mirroring `FILECAPS`) of everyone who'd be in the group afterward — never cached — refusing with a clear error otherwise; leaving is never gated by this. Already-saved groups (the old `Group.left`-overlapping shape) migrate once automatically on load. `MainActivity.showMembers()` sources departed members from the `allKnownMembers()` API, its Re-invite button runs on a background thread (`reinviteMember` does real network I/O), and each active member's row carries a "Synced"/"Catching up" tag (`PeerEngine.memberAckedVersion(groupId, peerId)` compared against `Group.membersVersion`). See `PLAN-GROUP-MEMBERSHIP.md` (source root).
- **2.0.1**: 2.0.0 briefly also shipped a join-request feature (any verified contact of a group's owner could ask to join by ID, with an owner accept/ignore queue in `showMembers()`, via `requestJoin`/`acceptJoinRequest`/`ignoreJoinRequest`, `JOIN_REQUEST_COOLDOWN_MS`, new `LM4\tJOINREQUEST`/`JOINREQUESTACK` frames and `J`/`Q` storage rows). **That feature has been removed** by explicit request — all of the above is gone from `PeerEngine.java`/`GroupSync.java`/`MainActivity.java`. The mutable-membership foundation above (`addMember`, capability checks, migration, `reinviteMember`, sync status) is untouched. A saved data file that still has old `J`/`Q` rows from before the removal loads fine (those rows are now silently skipped rather than rejected). Alongside the removal: `confirmDeleteConversation`'s dialog now says "Leave group?" (not "Delete conversation?") for a group, now also reachable via a new "Leave group" item in the open chat's overflow menu (`chatMenu`), not just the conversation-list long-press; and a new "Hide groups" side-menu toggle was added — see below.
- **2.1.0**: group ownership can now be handed off, closing the 2.0.1 gap noted above (nothing used to stop the owner from leaving their own group, silently orphaning it). New `PeerEngine.transferOwnership(groupId, newOwnerId)` (delegating to `GroupSync.transferOwnership`) — owner-only, requires a fresh live `CAPS>=2` from *every* current active member (refuses outright, nothing mutated, if anyone can't support it), and refuses if any member hasn't yet acked their first invite (the `GROUP` frame's sender-must-equal-claimed-owner invariant makes it impossible to deliver a first-time invite on behalf of a different owner mid-handoff). `Group.owner` had to become mutable (it was `final`) since it now updates immediately, everywhere, as part of adopting the transfer's snapshot — but the *old* owner must stay the delivery/leave-acceptance authority for this one change (not the new owner) until every other member has actually caught up, tracked via a new durable `pendingOwnershipHandoff` set (persisted as a new `O` row) that survives a restart; `deliver()`'s broadcast gate and `handleLeave`'s accept check are both widened to check it alongside `g.owner.equals(id)`. `MEMBERSUPDATE` gains a 6th (owner) field once a group has ever transferred (tracked via a new persisted `everTransferredOwnership`/`T` row); `CAPS` bumps its reply from `1` to `2`; `addMember` requires `CAPS>=2` (not just `>=1`) for any group that's ever transferred. `confirmDeleteConversation` shows a "Choose a new admin" picker instead of the normal confirmation when the owner tries to leave a non-empty group; the people-list row and open-chat heading both show "Leaving — waiting for members to catch up" (composer/send disabled) until the deferred departure actually completes. See [PLAN-GROUP-OWNERSHIP-TRANSFER.md](../PLAN-GROUP-OWNERSHIP-TRANSFER.md) — including why a simpler "wait for just the new owner" design (an earlier draft, caught on external review before any code was written) doesn't work, and the accepted limitation that remains (a member who never comes back online blocks the departure indefinitely).
- 0.8.12: long-press a conversation row for "Delete conversation" — clears its history/attachments and, for a contact, revokes verification and removes the peer record entirely (a group is left); a rediscovered forgotten contact reappears as a brand-new, unverified device. "Delete app data" in the side menu wipes every conversation/contact/group/attachment while keeping identity, display name, profile picture, and also resets the daily upload counter (`deleteConversation`/`deleteAllData` in `PeerEngine.java`).
- 0.8.12: deleting a contact now also notifies them. `deleteConversation`/`deleteAllData` queue a peer id in a persisted `forgotten` set; `deliver()` sends them a new `LM4\tFORGET` frame (retried until acked, same shape as `SEEN`/`SEENACK`) whenever that peer is next reachable, which calls `revoke` on their side and raises a new `forgottenCallback`, wired in `MessengerService.java` to a notification ("Removed you as a contact..."). Deleting a group is still a leave (unaffected for other members), but it now queues a `LM4\tLEAVE` frame to the group's owner (persisted `pendingLeaves`); the owner records the departed member in a new `Group.left` field (an optional 7th, backward-compatible `G` storage field, via `GroupSync.handleLeave`) and `deliver()`'s invite-resend loop skips anyone in `left`. `showMembers()` in `MainActivity.java` now shows departed members distinctly with an owner-only "Re-invite" button, calling the new `reinviteMember(groupId, memberId)`, which clears the Acknowledged/Left flags so the next delivery cycle resends the `GROUP` invite and they rejoin with the same member list — no re-verification needed. An old build that doesn't understand `FORGET`/`LEAVE` simply never acks; the sender keeps retrying rather than erroring.
- Messaging, groups, verification, blue/gray presence, attachment draft before Send, and local chat clear.
- Automatic inline ordinary photos and built-in camera capture with preview before sending.
- Initially render newest 10 messages, then 20 more when scrolling upward; MainActivity has a 16 MiB thumbnail LRU cache.
- Aggregate daily upload limits: unlimited below 2 GiB; 30 MiB/s at 2-5 GiB, 20 MiB/s at 5-10 GiB, and 10 MiB/s at 10 GiB and above. Usage appears in profile.
- Aggregated network reads/writes, timeout-watchdog cleanup, and encrypted FETCHSTREAM resume for the older private-cache path.
- Since 0.8.7: ACTION_CREATE_DOCUMENT destination choice, direct single-copy manual download, ACTION_VIEW opening, and 256 KiB direct resume.
- Fast file payload uses unencrypted TCP data with authenticated TLS control; ordinary files use TLS.
- Foreground service for background receipt, subject to Android battery and network restrictions.
- People-screen side menu opened from the header bar. It holds Profile and About, which moved out of the tools row, plus `Show offline users` and `Hide groups` switches.
- `Show offline users` is an Android-local `SharedPreferences` flag in `lan_messenger_ui`, default false. With it off, the filter runs in exactly one place: while the people screen builds its visible row list, and only for direct peers. An offline direct peer contributes no row. This is a display filter, not a state or routing rule. Engine state is unchanged — the peer, its messages, its unread count and any queued send are untouched — and nothing about it is filtered on the wire or in any protocol field. An incoming deep link and an already-open chat do not go through the list at all, so they bypass list visibility rather than being filtered by it, and either still reaches a hidden offline peer. The preference is read off the UI thread before the first render so the list never flashes unfiltered rows, and it is part of the list render signature, together with an explicit invalidation on toggle, so the rows and the empty-state hint always match the flag.
- `Hide groups` (post-2.0.0) is a second, independent Android-local `SharedPreferences` flag (`hide_groups`, same file), default false, mirroring `Show offline users` exactly: a display-only skip of every group row while the people screen builds its visible list, no engine/wire/routing effect, same deep-link/open-chat bypass, same read-before-first-render and signature/invalidation treatment. `PeopleListView.readHideGroups`/`setHideGroups`; the filter itself lives in `MainActivity.render()` alongside the existing offline-peer skip.

## Limits and unimplemented behavior

- The chosen Android document provider must support reading, writing, and seeking. Some cloud providers cannot support direct resume.
- Newest-10 is a UI construction optimization; `messages()` still scans engine-held message records.
- Complete view trees for several chats are not retained. Switching reconstructs the UI, helped by the message records and thumbnail cache.
- On a changed chat signature, the visible cards are rebuilt. This does not fully mirror Windows's current-card reuse.
- Daily limits are local to the app/device, not centralized enforcement against a modified app.
- Both the offline-peer filter and the Hide-groups filter are presentation-time only, live in the people-list presentation layer, and are Android-local. Windows has no equivalent setting, neither flag is ever sent on the wire, and this is a deliberate asymmetry rather than a protocol or compatibility gap. Because they never leave the Activity, neither can constrain `PeerEngine` state, message routing, or wire behavior.
- The side menu opens from its header-bar button and closes via the scrim, its Close button, choosing an action, or Back. It has no slide animation, no edge-swipe or drag gesture, and it stays open across a pause/resume cycle.
- If the preference write fails, the value still applies for the current session and is lost on restart.

## Verification and handoff

- Mutable group membership foundation: APK build and signature verification passed against the current working tree. Full `tests/run.ps1` passed, including `tests/group_membership.py` (cross-platform) — convergence on add/remove/re-invite, a device offline through several changes catching up in one step, a group shrinking to just the owner and regrowing past the creation-only `<3` floor, a live (never-cached) capability check that a reachable-but-uncooperative or genuinely unreachable peer both fail identically, an already-confirmed member later going uncooperative blocking further growth until they cooperate again, leaving never gated by anyone's capability, migration of an old-shape saved group on both platforms, and the 16-member cap enforced against the live roster (a real 16-process scenario, re-pointed at direct `REINVITE` add after the join-request layer it originally rode on was removed). New harness commands used: `REINVITE`, `LEFT` (now via `allKnownMembers`), `LEGACY`, `ROSTER`. No manual click-through of `showMembers()`'s updated display was performed in this environment.
- 2.0.1 join-request removal + Leave-group relabel (list + in-chat) + Hide-groups toggle: signed APK build and signature verification passed, and the full `tests/run.ps1` suite passed. Removing `addMember`'s join-request-auto-clear hook and `deleteAllData`'s join-request snapshot/clear/rollback fragments required surgical edits (not blanket deletion) to avoid disturbing the surrounding capability-check-then-mutate-then-save structure — verified byte-for-byte behaviorally unchanged by `group_membership.py`/`group_migration_broadcast.py` passing unmodified. The Hide-groups toggle and Leave-group relabel/in-chat entry point are Android UI changes with no automated interaction test (same limitation noted throughout this file for Android UI) — compile-verified via the signed build only. This environment has a long-lived, unkillable zombie `dotnet` process that intermittently causes transient TLS/timeout contention specifically under the heaviest 16-17-real-process scenario in a full-suite run — every such failure seen while preparing this release was independently reproduced-and-confirmed-clean on an isolated rerun before being treated as environmental rather than a regression.
- 2.1.0 group ownership transfer: signed APK build and signature verification passed, and the full `tests/run.ps1` suite passed, including the new `tests/ownership_transfer.py` (cross-platform, exercises both the Java and C# engine) — a basic transfer converges everywhere and the old owner's departure completes automatically once everyone has caught up, after which the new owner can grow the group; a transfer is refused outright if any member can't answer a fresh `CAPS>=2`; transferring to yourself or a non-member is refused; the pending handoff survives the old owner's own restart and still completes afterward; a transfer is refused while any member is still mid-onboarding. Not built: a dedicated test for a still-lagging member's `LEAVE` arriving specifically during the pending window — reliably forcing that exact race needs an artificial mid-flight pause this harness can't provide. The new "Choose a new admin" picker and "Leaving — waiting for…" state are Android UI changes with no automated interaction test (same limitation as every other Android UI change in this file) — compile-verified via the signed build only.
- 0.8.12 (forget-notice / group re-invite): APK build and signature verification with the original signing key passed against the current working tree, versionCode 22 / versionName 0.8.12. The full `tests/run.ps1` suite passed, including the extended `tests/delete_conversation.py`, which exercises the real Java engine for both new behaviors: contact delete followed by the other side's own verification being auto-revoked once the `FORGET` notice arrives (new `VERIFIED` harness command), and a non-owner group member leaving, the owner seeing them recorded in `left` (new `LEFT` harness command), re-inviting them (new `REINVITE` harness command), and confirming they rejoin and receive new group messages again. No manual click-through of `showMembers()`'s new "Re-invite" button was performed in this environment.
- APK build and signature verification with the original signing key passed.
- Java/C# engine interoperability, resume/disconnect, integrity, and daily-policy tests passed.
- A 1025 MiB Fast test passed on a computer with a 64 MiB Java test heap; that is not a physical-phone benchmark.
- Real-device acceptance is pending for destination chooser, file opening, camera, background behavior, and Wi-Fi throughput.
- Voice Messages (Phase 1): `VoiceMessages.java` (transport-independent PCM/WAV/marker/seek core), `VoiceDrafts.java` (draft registry + `sendVoiceDraft`, static methods on `PeerEngine`), `VoiceRecorder.java`/`VoicePlayer.java` (`AudioRecord`/`AudioTrack` adapters), `VoiceUi.java` (own-draft record/send UI), `VoiceCard.java` (receiver cards), `VoicePlayback.java` (shared one-active-player controller), `TransferManager.java` (`queueAutomaticMedia`, the renamed/extended scheduler). Tests: `tests/VoiceMessagesCheck.java` (AT01), `tests/voice_drafts_android.py` (AT02), `tests/voice_scheduler_android.py` + `tests/VoiceSchedulerCheck.java` (AT04, partial), `tests/voice_architecture_check.py` (AT06). Progress tracker: [PLAN-VOICE-MESSAGES-ANDROID.md](../PLAN-VOICE-MESSAGES-ANDROID.md).
- UI/cache: `src/net/lanmsg/chat/MainActivity.java` (`showMembers()`'s sync status, `confirmDeleteConversation`'s Leave-group wording and its `showTransferOwnershipPicker`, the Hide-groups filter and the "Leaving…"/"Leaving — waiting for…" rendering in `render()`). Side menu: `PeopleListView.java` (`readHideGroups`/`setHideGroups`). SAF/service: `MessengerService.java`. Direct transfer: `DirectFileTransfer.java`, `DownloadDestination.java`. Legacy encrypted path: `ResumableTransfer.java`, `ResumeStore.java`. Upload tiers: `DailyUploadPolicy.java`. Groups (live membership, `CAPS`, `addMember`, migration, `memberAckedVersion`, ownership transfer): `GroupSync.java`/`PeerEngine.java`.
- Current Android package: `D:/LAN-Messenger/outputs/LanMessenger-2.1.1.apk`; install over the existing app without uninstalling, after checking `outputs/SHA256SUMS-Android-2.1.1.txt`. The 2.1.0 APK is the prior package, retained for reference; test outputs: `D:/LAN-Messenger/outputs/.build/release-tests-087`.
- Last Android code commit: `7d9d99c`; the people side menu, delete-conversation/delete-app-data, forget-notice/group-re-invite, the 2.0.0 group-membership foundation + (later removed) join-request layer, the 2.0.1 join-request removal + Leave-group relabel, and the 2.1.0 group ownership-transfer feature committed locally on `master`, not pushed.

### People side menu and offline filter: implementation, automated verification, device acceptance

Implemented and packaged in 0.8.12 (code, not yet accepted on a device):

- `MainActivity.java` only. `android/STATUS.md` and `PROJECT_STATUS.md` are the other changed files. No engine, protocol or Windows file was touched, and no dependency was added.
- The content view is now one full-screen `FrameLayout` stage holding the existing chrome column, so the menu overlays the whole screen including the header bar without altering the layout each screen builds.
- Menu contents: Profile, About, `Show offline users`, and a one-line explanation. Profile and About are the same actions as before, moved out of the tools row; Refresh, Add by IP, New group and the avatar stayed on that row.
- The one filter is a single skip inside `render()` while it builds the visible conversation list, and it applies to direct peers only. `PeerEngine.peers()`, `messages()`, `unread()`, `groups()` and `pending()` are unchanged, and the header status line still reports the real online and queued counts. The deep-link path calls `showChat` directly and never reads the flag, so an incoming deep link or an already-open chat bypasses list visibility instead of being filtered.
- Back closes an open menu first, then falls through to the previous chat-to-people and exit behavior.

Automated verification passed (no device or emulator was used):

- The project's `android/build.ps1` pipeline completed: javac, jar, d8, aapt, zipalign, apksigner sign, apksigner verify. It was not the unmodified script that ran to the end — see the known build-script issue below; the successful run used a temporary copy with only that one line neutralized, and the working-tree `android/build.ps1` is otherwise unchanged (its output filename now points at `LanMessenger-0.8.12.apk`). Verified v2 and v3 APK signature schemes, one signer, `net.lanmsg.chat` versionCode 22 / versionName 0.8.12, minSdk 26, targetSdk 34. No signing material was read or printed.
- The compiled `MainActivity.class` from that build was disassembled with `javap` and contains `openMenu`, `closeMenu`, `barButton`, `menuItem`, `readShowOffline`, `setShowOffline`, the `stage`/`menuOverlay`/`menuOpen`/`showOffline` fields, the `lan_messenger_ui` and `show_offline_users` keys, and the new user-visible strings. The same check on the `onBackPressed` and `setShowOffline` bytecode confirms menu-close-before-navigation and the persisted write.
- Full `tests/run.ps1` suite passed, including the Java and C# engine tests, all interoperability, transfer, resume, group and policy suites, and the Windows native UI tests. This is regression cover for the unchanged engine, not cover for the new Android UI.
- Known build-script issue, pre-existing and not caused by this change: under Windows PowerShell 5.1, `build.ps1` sets `$ErrorActionPreference = 'Stop'` on line 7, so javac's `Note: Some input files use or override a deprecated API.` on stderr aborts the script even though javac exits 0. A direct invocation of the unmodified `android/build.ps1` therefore stopped at that point and produced no APK. The unmodified script as of commit `0c66207` produces the same note, and the same note is produced with and without this change. The verification build therefore ran the script with only that one line neutralized, through a temporary copy placed in `android/` and deleted afterwards, so every tool, path and signing input was the project's own. `build.ps1` itself was not modified.

2.0.1 addendum: a second, independent `Hide groups` switch was added to the same menu, same pattern (`PeopleListView.readHideGroups`/`setHideGroups`, a new `hide_groups` key in the same `lan_messenger_ui` preferences file, the same single-skip-in-`render()` shape, this time for group rows). Verified by a clean signed APK build only — no `javap` bytecode check or device acceptance was performed for this specific addition.

Device acceptance of this historical 0.8.12 menu/filter work was not started at the time: no phone or emulator was used for those UI checks, and the packaged 2.1.1 APK remains unaccepted. Still to check by hand: the menu opens, closes and overlays the header correctly; both switches hide and restore their rows live, independently of each other; Back closes the menu without leaving the screen; both flags survive an app restart; an all-hidden list shows the correct hint; a deep link still opens a hidden peer's or group's chat; unread counts, avatars, Refresh, Add by IP and New group behave with rows hidden.

## Next proposed check

Acceptance on two physical phones: destination choice, connection interruption/resume, Open, background receipt, and throughput. Engine tests alone do not complete this acceptance check.

Device/click-through acceptance of the mutable-membership foundation's UI (Members dialog sync status, Re-invite), the 2.0.1 changes (Leave-group wording and its new in-chat entry point, the Hide-groups toggle), and the 2.1.0 ownership-transfer UI (the "Choose a new admin" picker, the "Leaving — waiting for…" state) is still outstanding — none of this has been exercised on a real device or emulator. See `PLAN-GROUP-MEMBERSHIP.md` and `PLAN-GROUP-OWNERSHIP-TRANSFER.md`.

## Voice Calls — Phase A0 foundation (2026-10-01, plan-v006)

Phase A0 shared architecture and contracts (B00/B01) are code-complete. These are pure-Java
design contracts — no WebRTC dependency, no networking integration with PeerEngine, no UI, no
production packaging. All classes compile with the existing javac/d8 pipeline; all 75 unit
tests pass.

New source files in `src/net/lanmsg/chat/`:

- `CallProtocol.java` — 14 signaling message types (INVITE through PONG), 6 call states,
  quality-indicator constants, invitation-limiter (5/peer/60s rolling window), glare
  resolution, and all timing/defaults from plan-v006.
- `CallSignaling.java` — 4-byte big-endian length + UTF-8 JSON frame serialization and
  parsing, with convenience builders for every message type.
- `CallSession.java` — Immutable call snapshots (caller/callee direction, state, mute,
  audio route, quality, duration) for thread-safe UI consumption.
- `CallController.java` — Main orchestrator: state-machine enforcement, signaling dispatch,
  media lifecycle (via injectable `ICallMedia`), invitation throttling, ring/media-setup
  timeouts, Connected heartbeat, quality polling, Offline cleanup, and engine-shutdown.
- `ICallMedia.java` — Media-adapter interface + Factory (Opus, DTLS-SRTP, SDP/ICE, mute,
  capture/playback, WebRTC cumulative statistics). A fake implementation (`FakeCallMedia`)
  ships alongside for testing.
- `CallSettings.java` — Incoming-call preference (default: enabled), persisted atomically
  per device in a separate `call-settings.txt` with a generation counter to reject stale
  writes. Corrupt settings disable incoming calls for that session.
- `CallQualityMonitor.java` — Pure-Java evaluator consuming WebRTC-style cumulative stats;
  first/last-sample deltas over a 5-second rolling window; 3 consecutive degraded evaluations
  to enter Reduced; Normal immediately on recovery.
- `WebRtcCallMedia.java` — Production media adapter using org.webrtc reflection-based API.
  Uses webrtc-sdk:android:150.7871.01 AAR (PeerConnectionFactory, AudioSource/AudioTrack,
  SDP offer/answer, ICE, stats). Requires native libjingle_peerconnection_so.so at runtime.
  Uses a dedicated `HandlerThread` and a single-thread callback executor, with a process-global
  refcounted `PeerConnectionFactory` and `JavaAudioDeviceModule`. LAN-only ICE (no STUN/TURN).
  **Installed in the service** (`MessengerService` probes the native stack, then installs this
  factory, falling back to `FakeCallMedia` only if the probe fails). `probe()` reported
  `WebRTC native stack OK in 20 ms; hwAEC=true hwNS=true` on the SM-S908E.
- `CallUi.java` — Service-owned call view-model (no Android dependency). Plan-v006 wording for
  state/detail/end labels (`Declined` for both manual and policy decline, never disclosing the
  preference), duration formatting, the Reduced quality hint, accept/decline/cancel/hangup/mute, and
  an observer list so an Activity can bind without displacing the service's notification. Retains
  the terminal snapshot so the end reason outlives the controller's return to Idle.
- `CallChannel.java` — Owns the call socket, one reader thread and a serialized writer for both
  directions. Implements `Transport` and `Closeable`; the opening INVITE is routed to `onInvite`
  while later frames go to the controller.
- `CallNotifier.java` — `calls_ringing` (IMPORTANCE_HIGH, the only alerting channel) and
  `calls_active` (IMPORTANCE_LOW, silent); ringtone playback; Accept/Decline service intents
  carrying the call ID; Accept opens `MainActivity` so the permission flow is visible.
- `CallView.java` — In-Activity call overlay on `stage`. Rebuilt per state change; duration on the
  1 s tick; terminal banner expiring after 2500 ms; one-shot quality announcement.
- `CallRoute.java` — Carries a route decision to `AudioManager`: `MODE_IN_COMMUNICATION`, and the
  built-in speaker or earpiece on API 31+. Only switches when the user chose the speaker, so a
  headset the platform itself selected is never overridden.
- `AudioOwnership.java` — Arbitration between voice calls and voice messages. Service-owned,
  pure Java. Recording is refused while a call rings/connects/captures; playback is refused while
  a call owns the device; a call may start over playback but recording interrupts it first.
  Guarded `releaseIf(owner)` is the only release used by the voice side.
- `CallRoutePolicy.java` — Route *selection*, separated from route application. Earpiece is the
  default and speaker is never an automatic first choice; a wired headset outranks the earpiece;
  a lost route is held for the 3 s `ROUTE_RECOVERY_MS` window before falling back; a user-selected
  route is never silently overridden while missing; proximity applies only on earpiece; no route
  at all is a distinct failure rather than a silent fallback.

Test: `tests/CallCheck.java` — **229 unit tests** covering protocol transitions, signaling
serialize/parse round-trips (including oversized/malformed rejection), settings
persistence/reload/generation, quality degradation/recovery via deterministic sequences,
invitation-limiter bounds/window-expiry/prune, controller lifecycle/shutdown, incoming-call
dispatch, decline, disabled-policy rejection, mute, frame-parse edge cases, glare/duplicate
INVITE idempotency, settings corruption, audio-ownership state machine and its controller
lifecycle, and route selection including the recovery window; plus (A08–A10) invitation replies
never being silent (policy → DECLINE, throttled/occupied → BUSY, identity mismatch → silence),
malformed call ID refused, RINGING confirming the ring window, policy withdrawal of a ringing
call, stale-`accept(callId)` refusal, uniform terminal wording, listener fan-out surviving
rebind and isolating a throwing listener, audio route in the snapshot, and UI label
distinctness/duration formatting.
`CALLCHECK PASS=229 FAIL=0`.

Modified: `PeerEngine.java` (+CALLCONNECT protocol, +callHandler, +onRevoke,
+openCallConnection), `MessengerService.java` (+CallController +CallSettings +AudioOwnership,
lifecycle wiring), `VoiceUi.java` / `VoicePlayback.java` (+audio-ownership claims and releases,
including the awaited release on the recording stop thread), `AndroidManifest.xml`
(+MODIFY_AUDIO_SETTINGS, +extractNativeLibs=true, +microphone feature optional,
`foregroundServiceType="connectedDevice|microphone"`, +FOREGROUND_SERVICE_MICROPHONE).

Not yet done (all device-dependent): A04 real media install, A07p proximity sensor,
`AudioManager` route application, runtime microphone foreground-service behavior.

Build: `prepare-webrtc.ps1` downloads the WebRTC AAR; `build-voice.ps1` produces an
integrated APK with native .so libraries. See
`.ai-planner/sessions/20260930-091333-43c139/state/` for all handoffs and the A00
evaluation report.

## Third pass on the same work (2026-10-02, 2.2.34)

**A cold start could not answer an incoming call.** Tapping **Accept** did nothing at all — no
`ACCEPT` frame, no toast, no error, no visual change, and the call rang out. **Decline worked**, and
every screenshot looked correct, so nothing about the screen hinted at it.

Two references to one view-model were involved. `CallView.render` reads the service's instance via
`activity.host.calls()`, while `acceptCall` read the Activity's own `callUi` field and returned
silently when that was null. The field is bound only from `onResume` and `onServiceConnected`, but
the service does not create its `CallUi` until it builds the LAN stack — seconds after both of those
— so neither attempt found one, and **nothing ever asked again**. Decline survived because it
captures the instance it was built with. The same defect made the notification's Accept action inert
and made Back navigate away from a live call instead of minimising it, for as long as the user did
not leave and return.

Fixed three ways: `render()` retries the bind on its one-second pass; the Accept button acts on the
model that drew it (`CallUi.resolveForAccept`, `N179`-`N183`); and no path returns silently any more
— the notification action and `onBackPressed` fall back to the service's instance and, failing that,
say so instead of doing nothing. Verified on both phones from a cold start, with one tap and no
re-entry (`accept-coldstart.ps1`, `X0`-`X6`, all pass on 2.2.34).

**The peer's name could go stale for a whole call.** The call screen's rebuild test was a chain of
`||` clauses over call ID, state, mute and route, and the peer's *name* was not among them: a contact
renamed mid-call kept the old name, the old initial on the picture, and three accessibility labels
naming them wrongly until something unrelated forced a rebuild. Replaced by a single
`CallUi.overlayKey` string (`N171`-`N178`).

**TalkBack fix completed.** The earlier fix gated a new announcement on state transitions but left
the status line as a permanent live region being rewritten once a second, so the clock was still
read aloud every second and the new code merely added a second announcement path. The live region is
now removed from both the full screen and the collapsed bar, the announcement moved above the
collapsed/full split and the rebuild test (both return early, so transitions that rebuild — including
answering — were never spoken), and `CallUi.stateSpokenLabel` says "Connected" rather than the clock
value `stateLabel` would give (`N167`-`N170`).

`tests/CallCheck.java` **PASS=387 FAIL=0**. Build 2.2.34 (versionCode 61) installed on both phones,
same signer as every prior release.
## Fourth pass on the same work (2026-10-02, 2.2.36)

**The conversation control did nothing.** Tapping 💬 on the call screen opened the conversation and
then lost it: `showChat` ends in `frame`, which ends in `CallView.forgetOverlay`, and that cleared the
dismissal the button had just recorded, so the next `render` rebuilt the full call panel over the
conversation in the same tap. A comment above the button already described this exact failure and
claimed it was fixed; `forgetOverlay` undid it. `forgetOverlay` now drops only view references --
`collapsed` and `dismissedCallId` record what the user asked for, not anything about the discarded
tree -- and `CallView.returnToCall` lifts the dismissal from the Return control, which without it
would have had nowhere to go. Verified on both phones: the conversation opens, the call screen stays
down, and the call keeps running.

**A live call had no way back from the conversation.** `callBar` was built only into the people
screen, and its comment claimed it "stays across the top of every screen". With the conversation
control fixed, opening the chat led somewhere with no call controls at all -- indistinguishable from
the call having ended. `buildCallBar` is now shared by both screens.

**The minimised call is now a floating, draggable bar.** It was a full-width strip anchored to the
foot of the stage, which is exactly where the message box and its keyboard appear, so a call and
typing could not both be used. It is sized to itself, floats, and can be dragged anywhere: a
`GestureDetector` tells a tap (reopen) from a drag (move) with a 6 dp slop, the click listener is kept
for accessibility activation, and the hang-up button is a child so it takes its own touches first.
Every position is pulled back inside the stage (`CallUi.clampBarLeft`/`clampBarTop`, `N184`-`N192`),
which is skipped before the first layout pass when neither size is known. The position is kept outside
the view tree -- the bar is rebuilt on every state change, so a position held in the view would be
lost each time -- and persisted so it survives calls and restarts.

`tests/CallCheck.java` **PASS=396 FAIL=0**. Build 2.2.36 (versionCode 63) installed on SM-ultraaysar;
SM-A075F went `unauthorized` on adb before it could be installed, so the two-device run of this round
is outstanding.
## Fifth pass on the same work (2026-10-02, 2.2.39)

**The floating bar trailed the finger.** The drag accumulated the per-event deltas that
`GestureDetector.onScroll` hands over. The detector only starts reporting once the finger has left the
tap region, and up to that point it measures from a focus point it smooths as the gesture goes on,
so the bar landed well short of the finger and stopped wherever the smoothing ran out: on the phone, a
227px swipe moved the bar 148px. The bar is now placed against the finger's position relative to where
it went down (`CallUi.draggedLeft`/`draggedTop`), which is also the only version that cannot drift
across the events of one gesture. Measured on SM-ultraaysar: a 646px drag moved the bar 636px and a
1087px one moved it 1082px -- within 1px across and 5-10px down.

`CallUi.isBarDrag` holds the tap/drag decision at the 6dp slop, on either axis, so a tap that reopens
the call never nudges the bar and a short sideways drag is still a drag. `N193`-`N204`.

`tests/CallCheck.java` **PASS=408 FAIL=0**. Build 2.2.39 (versionCode 66) installed on both phones.

## Call history entries in chat, Messenger-style (2026-10-02)

The user asked for inline call-history entries in the conversation, Messenger-style: "You called
X", "X called you · 5:30", "Missed call". Implemented per
[PLAN-CALL-LOG-ANDROID.md](../PLAN-CALL-LOG-ANDROID.md) as a **purely local** annotation — each
device logs its own call outcome from its own `CallController`'s perspective (caller/callee role,
connect time and duration are already known identically on both ends without either side telling
the other), so there is no wire/protocol change and nothing new is ever sent to the peer.

New `CallLogMarker.java` encodes `isCaller`/`connected`/`durationMs` into a message's `fileName`
(mirroring `VoiceMarker`'s own filename-convention trick, not a new LMSTORE4 row type). New
`PeerEngine.appendCallLog` builds and persists that `Message` directly with `status="Delivered"`
from the start — never `"Queued"`, so `deliver()`'s retry loop (which only ever looks at Queued
rows) never picks it up for network send. `from`/`to` are set so the existing mine-vs-theirs
bubble gate falls out for free: an outgoing call's entry has `from=my id`, an incoming call's has
`from=peerId`. Hooked into `MessengerService.onCallSnapshot`'s `case Ending:` — the single point
where `CallController.endCall()` delivers a snapshot with both the final duration and whether the
call ever connected together. `MainActivity.render()` detects a call-log message before the normal
bubble path and renders it as a centered system-style pill (📞 icon, no sender name/avatar row, no
delivery ticks, a timestamp underneath) — not a chat bubble, matching Messenger's actual visual
treatment. Missed calls (callee side, never connected) are tinted red.

**Verified on-device across a real multi-call test between both phones**, covering all four label
variants in the same session: "Missed call" (a connection that failed before connecting), "You
called ultra · 0:03" / "You called ultra" (caller side, with and without a connected duration),
"ultra called you · 0:08" / "ultra called you · 0:02" (callee side, connected with duration), and
a second "Missed call" from a declined ring — each with a matching timestamp on both devices, and
full symmetry confirmed: the same four calls appear correctly worded from each side's own
perspective (e.g. device A's history reads "You called ultra · 0:03" for the exact call device B's
history reads as "SM-A075F called you · 0:03"). Real javac compile (0 errors) and a full
`build-voice.ps1` build/sign/verify pass. No wire, storage-format, or Windows change.

**Released as 2.2.42** (versionCode 69): `android/build.ps1` (the real release entry point)
built, signed and verified (v2+v3, original signing key continuity confirmed via
`apksigner verify --print-certs`). Installed on both physical devices over their existing
installs (no uninstall needed); both relaunched cleanly with no crash, both back Online and
mutually Verified. `outputs/LanMessenger-2.2.42.apk`,
`outputs/SHA256SUMS-Android-2.2.42.txt`.

## Compose row: Messenger-style icons, camera photo+video, gallery photo+video (2026-10-02)

The compose row was five text buttons (Camera, Photo, File, Fast file, plus a separate text Send
button); the user asked for it to look and behave like Messenger's, specifically: icons instead
of text, the camera icon letting them record a video or take a photo (previously photo-only —
there was no video capture anywhere in the app), and the gallery icon letting them pick a photo
or a video to upload (previously image-only).

Implemented per [PLAN-COMPOSE-ICONS-ANDROID.md](../PLAN-COMPOSE-ICONS-ANDROID.md) (C01-C05, all
done), after confirming three design choices with the user: the system camera with a Photo/Video
chooser first (not a full custom in-app camera screen), Send becoming an icon too
(paper-plane/thumbs-up), and File/Fast file folding into a "+" popup menu.

`AttachmentFlow.captureVideo` (new) mirrors the existing `capturePhoto` but with
`MediaStore.ACTION_VIDEO_CAPTURE`; `chooseCameraMode` (new) is the Photo/Video chooser dialog
the camera icon opens. `CameraAttachmentProvider` (the content provider that grants the system
camera app write access to one app-private capture file) now accepts both `.jpg` and `.mp4`
capture targets and reports the right MIME type for each — still keyed only by this app's own
generated cache filename. `pickFile`'s `photo` parameter now means "media": the gallery picker
requests `{"image/*","video/*"}` instead of `image/*` alone, so one picker returns either, same
as Messenger's single gallery entry. The row itself uses a new `composeIcon` helper (neutral
light-gray circle) rather than `dotButton`'s translucent-on-dark style, which was tuned for the
call screen and would have been invisible against this screen's light background. Send gained a
`refreshSendIcon()` that swaps ➤/👍 based on whether there's a message or attachment ready,
wired to the composer's text watcher and to the attachment draft being set/cleared.

**A real bug was found and fixed during this work, not a pre-existing separate report:**
`render()` had its own hardcoded `send.setText("Send")` on every per-second refresh pass, left
over from the old text-button Send, which silently overwrote the new glyph back to literal
"Send" text every render tick. Caught by observing the on-device screenshot (not by the
compile), fixed by replacing it with a conditional `refreshSendIcon()` call.

**Verified:** real javac compile of all 42 production files, 0 errors; full `build-voice.ps1`
build/sign/verify succeeded (twice — once before, once after the render() fix). **On-device
acceptance** (one device; this is OS-intent/UI behavior, not peer-dependent, so no two-device
run was needed): Send correctly shows 👍 empty / ➤ with content, live as you type; `+` opens
File/Fast file; camera icon's "Take photo" still works (regression-checked) and "Record video"
opens the system camera in actual video mode, and a real ~3 s recording was captured, attached,
sent, and rendered correctly as a first-frame thumbnail with the play-disc overlay (full
integration with the prior media-preview work, no regression); the gallery picker now shows both
"Images" and "Videos" category chips, where only images were selectable before.

## Video polish: draft preview, real play/pause, automatic receive, time bar (2026-10-02)

Four gaps found immediately after using the shipped camera/gallery/media-preview work, all fixed
in the same session — see [PLAN-MEDIA-PREVIEW-ANDROID.md](../PLAN-MEDIA-PREVIEW-ANDROID.md)'s
"Follow-up round" section for the full write-up (M07-M10). Summary:

- A video attached via the camera or gallery icon now shows a real first-frame preview **before**
  Send, same as a photo always did (`AttachmentFlow.renderPendingAttachment`, new
  `PeerEngine.isVideoFile`, new `AttachmentFlow.previewFrame`).
- A single tap on an inline video now genuinely pauses and resumes in place — the first version
  always rebuilt a fresh player on every tap, so a second tap during playback started a duplicate
  overlapping playback instead of pausing. Fixed with an explicit state machine
  (`MediaCard.InlineVideo`/`toggleInline`: `IDLE → LOADING → PLAYING ↔ PAUSED`).
- A received video now auto-downloads exactly like a photo (`TransferManager.queueAutomaticMedia`
  widened from `isImageAttachment` alone to `isImageAttachment||isVideoAttachment`, same pool/
  fairness/retry rules) rather than sitting behind a manual Download tap the way a plain File or
  Fast-file attachment does.
- The inline player gained a WhatsApp/Messenger-style time bar: an elapsed/duration label and a
  draggable `SeekBar`, visible even before the first tap, updated live via a self-rescheduling
  300 ms poll while playing (`MediaCard.tick`), reset cleanly on natural completion.

All verified on-device: two different real camera recordings showed correct draft previews before
sending; play → pause (frame froze, confirmed static across a timed wait with no tap) → resume
(continued from the same point, not a restart) → natural completion (clean reset) all behaved
correctly; a received video rendered as a clean thumbnail with no Download button before an
unrelated ADB "incremental install" serving-session glitch interrupted that specific device (not
an app exception — resolved by a clean uninstall/reinstall); the time bar tracked live playback
position end-to-end on a full play-through and reset correctly on completion. Real javac compile
(42 files, 0 errors) and a full signed `build-voice.ps1` pass after each change. No wire, storage,
or Windows change.

## Release 2.2.41: a real on-device crash found and fixed during release testing (2026-10-02)

Packaging today's work as a real numbered release (2.2.40, then 2.2.41) surfaced a genuine crash
that none of the dev-build testing above had hit: going online on a device with no previously
granted `RECORD_AUDIO` crashed the whole process with `SecurityException: Starting FGS with type
microphone ... requires permissions ... RECORD_AUDIO`. The manifest declares the service's
foreground-service type as `connectedDevice|microphone` (added for voice calls/messages), and
Android 14+ refuses to start a foreground service with a declared type whose matching dangerous
permission isn't *currently granted* — not merely declared — killing the app outright rather than
degrading. This is latent in every build since the voice-call work landed; it was never hit
before because every device used for testing already had `RECORD_AUDIO` granted from earlier
voice-message/call use. It surfaced here because an earlier uninstall/reinstall (done to clear an
unrelated ADB "incremental install" artifact) reset that device to a clean permission state.

Fixed in `MessengerService.java`: new `startForegroundSafely()` checks `RECORD_AUDIO` at the
moment `startForeground` is actually called (API 29+) and only includes
`FOREGROUND_SERVICE_TYPE_MICROPHONE` in the type bitmask when it is genuinely granted right now —
`FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE` alone (this service's whole reason for being
foreground) is always a safe subset of what the manifest declares, so going online can never
depend on a microphone permission unrelated to networking. Also closes an existing gap: per-call
`onRequestPermissionsResult` handling (`MainActivity.java`, both the voice-message recording grant
and the call microphone grant) now calls `startForegroundSafely()` again right after the user
grants `RECORD_AUDIO` mid-session, upgrading the already-running foreground service to add the
microphone type — this is the "A06 runtime microphone FGS promotion" item earlier status entries
had flagged as untested/unimplemented; it was actually just missing.

**Verified:** real javac compile (42 files, 0 errors); `build.ps1` (the real release entry point,
not `build-voice.ps1`'s dev-suffixed path) built, signed and verified **2.2.40** then **2.2.41**
(after this fix), both v2+v3, same original signing key continuity. Installed 2.2.41 on both
physical devices. The previously-crashing device now opens cleanly and goes Online without
incident. Full round-trip re-verified on the release build itself: re-discovered the peer (whose
identity necessarily changed after the earlier uninstall), mutual safety-code verification on
both devices, and a real text message sent from the reinstalled device arrived and showed
**Delivered** on the other — confirming the actual release artifacts work end-to-end, not just the
dev builds used during feature development.

`outputs/LanMessenger-2.2.41.apk` is the current release; `outputs/SHA256SUMS-Android-2.2.41.txt`
has its hash. 2.2.40 (pre-fix) is superseded and was not device-tested before 2.2.41 replaced it.

**Fifth gap (same day): the fullscreen double-tap view opened like a photo, not a video.**
`AttachmentFlow.previewVideo` showed only a static frame plus Download/Close — no actual playback,
which is exactly what a photo's fullscreen view shows too, so the two were indistinguishable.
Rebuilt around a real `VideoView` (same cached decrypted file as inline playback) with Android's
standard `MediaController` transport overlay, autoplaying on open and stopping cleanly on any
dismiss path. Verified on-device: screenshots taken seconds apart showed the frame had genuinely
advanced each time, through to content matching the clip's final seconds — real continuous
playback, not a picture. Compile/build/sign verified the same way as every other fix in this
round.

## Media preview cleanup: photo/video thumbnails, Messenger-style (2026-10-02)

A received photo rendered its inline thumbnail correctly, but a generic attachment card
(filename/size line, button row) still rendered underneath it regardless, and that row grew a
**second, redundant "Open" button** whenever the thumbnail existed — one tied to the generic
download/open-file action, one tied to the inline preview, both visible at once. Root cause:
`MainActivity.render()`'s non-voice attachment branch always built the generic card and only
conditionally bolted the extra button on, rather than treating "a preview exists" as a reason to
skip the generic card entirely. Video attachments had no preview concept at all — `isImageAttachment`
only recognized image extensions, so any video fell straight through to the plain file card.
There is no video-capture/send flow on Android (confirmed with the user); a video only ever
arrives as an ordinary file-picker attachment.

Fixed per [PLAN-MEDIA-PREVIEW-ANDROID.md](../PLAN-MEDIA-PREVIEW-ANDROID.md) (M01-M06, M06 skipped
as unnecessary scope): new `MediaCard.java` renders a single Messenger-style thumbnail with no
surrounding text/buttons when a preview exists (photo: the existing `inlineBitmap` decode; video:
a first-frame extraction via `MediaMetadataRetriever` against a one-time decrypted cache copy of
the attachment, `PeerEngine.isVideoAttachment` added for the extension check). A video thumbnail
gets a centered play-disc overlay; single tap plays it inline via `VideoView` (auto-restoring the
thumbnail on completion or error), double tap opens the same fullscreen view as a photo
(`AttachmentFlow.previewVideo`, new — a video's bytes are never valid image bytes, so it reuses
the cached frame rather than calling `previewImage`). `AttachmentFlow.previewImage`'s fullscreen
dialog gained a **⬇ Download** button next to Close, wired to the existing `exportFile`. The
original generic file card (filename, size, Open/Download/Resume) is unchanged and is still what
renders for anything with no local preview yet (not downloaded, too large for the image cap, or
an unsupported type) — confirmed on-device for an un-downloaded video, which correctly shows
Download rather than attempting a broken preview.

No size cap was added for video thumbnail generation (explicit user decision): extracting a frame
streams the decrypted attachment to a cache file rather than holding it fully in memory, unlike
the image path's `THUMBNAIL_PREVIEW_CAP`-guarded `inlineBitmap`.

**Verified:** real javac compile of all 42 production files against `android.jar` + the WebRTC
AAR, 0 errors; full `build-voice.ps1` pipeline (javac/d8/aapt/zipalign/apksigner) succeeded,
v2+v3 signature verified. Built as `LanMessenger-2.2.39-media-preview-dev.apk` (a validation
build, not a numbered release). **Two-device on-hardware acceptance passed in both directions**:
existing photo history renders thumbnail-only on both phones; a real 3.8 MB `.mp4` sent as a file
attachment rendered thumbnail+play-disc immediately on the sender and as the correct
download-first generic card on the receiver, converting to the same thumbnail+play-disc card once
downloaded; single tap played it inline on both phones (confirmed via `dumpsys audio` showing a
real `USAGE_MEDIA/CONTENT_TYPE_MOVIE` audio-focus request/release spanning the clip's actual
duration) and cleanly restored the thumbnail afterward; double tap opened the fullscreen view with
filename, ⬇ DOWNLOAD, and CLOSE on both the photo and the video. One transient, self-recovering
ANR was observed once after a heavy manual history scroll — consistent with pre-existing
synchronous image-thumbnail decoding in `render()` (true before this change too), not a
regression, and not seen again in the rest of the session.
