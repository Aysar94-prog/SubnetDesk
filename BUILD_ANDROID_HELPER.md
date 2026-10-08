# Private Android helper build on Windows

2026-10-08. Approved side-by-side candidate workflow; build support only.
Windows1.3.3+78 binary/source12a8dac archives remain frozen and are not replaced.
Native Android release now PASS2m02s: rebuilt ARM64 library22,912,088 bytes,
SHA2560656543E040A24A09B796974F7CA13AABF7CD53A8135EEC855EC26BE6BEEE1EC;
JNI copy matches, LOAD alignment0x4000 and JNI_OnLoad/Java_ffi exports verified.
115 compiler warnings are recorded, not compared with an Android baseline.
APK release PASS1164.2s; verified/staged1.3.3/code2078, helper identity/label,
arm64-only, no CAMERA permission, v2 signature and16KB ZIP alignment. AGP strip
reproduced from rebuilt input; APK library SHA256
B0E892CDC90F86BBB5D0B3A37963AD02E27D5A0B1A4761F65C39AFB81C4CDD36 matches.
APK SHA256 A36585E60E9ADB5341B87FD8EF51A40F2A520BDA130CEA8C486449A57782341F.
Installed beside official1.3.0/code2075, whose update timestamp/version are unchanged.
am start cold PASS441ms; helper PID24079 alive and scoped startup log snapshot contains
no matching native-loader/fatal/Flutter errors. This is startup smoke only, not UI or
paired acceptance. Microphone/notifications not yet granted to the new helper; user handling.
Phone has4KB pages;16KB physical-device acceptance not inferred from ELF/ZIP checks.
The profile's
RUNPATH contains a non-resolving Windows build-tool path; no Windows shared
libraries are required, and Android loader startup still needs device verification.
Paired screen/control/voice/camera-denial/buzzer/ring/mute acceptance still pending.

## Pinned inputs and isolation

- Rust1.82.0, aarch64-linux-android; cargo-ndk3.1.2.
- SDK36, NDK28.2.13676358/r28c, Temurin17.0.20.1+1, Flutter3.44.1.
- vcpkg baseline120deac3062162151622ca4860575a33844ba10b; original native
  libraries plus separately built Android libsodium1.0.20/OpenSSL3.5.2.
- Process-local environment and separate C:/Users/user/AppData/Local/SubnetDesk-build
  output roots; original Windows toolchain/junction and phone package untouched.
  The first Gradle attempt uses the ordinary user .gradle tool cache; subsequent
  build script runs set GRADLE_USER_HOME to the scoped gradle-user-home directory.
  Extra SDK platforms31/34 and CMake3.22.1 were installed in the scoped SDK by Gradle.
- Candidate Gradle property subnetdeskHelperCandidate=true selects
  com.zibochen.subnetdesk.helper, SubnetDesk Helper label and debug test signing.
  Never use LAN Messenger's key or replace the official package.
  Flutter's arm64 split adds2000 to the base build78, so expected manifest code2078.
  Candidate test certificate SHA25643e19ba2d0d80033f363eb733efcef4d33dd0ab0bb6b06f1115cd71e47057c52.
  Its private key is preserved under the scoped .private directory, never archived.
  Build script refuses future builds if the default debug signer differs from that
  preserved copy; never silently sign an incompatible helper upgrade.

## Build-script repairs

Root build.rs must inspect CARGO_CFG_TARGET_OS before compiling Windows C++, because
build-script cfg describes the host rather than the Android target.

Pinned hwcodec source778df1f99597722473b29443bac22ae6c23946fe is exported into a
scoped dependency directory, not edited inside Cargo cache. Apply
res/build/android-hwcodec-hostfix.patch to that export. It only makes two Windows
build branches target-aware and honors VCPKG_INSTALLED_ROOT. Use an Android-only
Cargo config paths override to select that exported source; Cargo.toml/Cargo.lock
and default Windows dependency selection stay unchanged. Rust1.82 warns about
path-override dev/capture source identity; no capture dependency is built for this
Android release. Record the warning and verify the lock file is unchanged.
This override is scoped to the pinned toolchain, not a general future-Cargo promise.

Set CFLAGS/CXXFLAGS_aarch64_linux_android to final target
--target=aarch64-linux-android21, because newer cc emits a bare target that otherwise
resets the minimum Android API. Bindgen uses NDK sysroot, Clang19 resource includes,
ABI includes and a forward-slash native include path. Keep Windows-host MSVC link.exe
explicit so MSYS GNU link.exe cannot shadow it.

Use cross-built static OpenSSL via OPENSSL_NO_VENDOR=1/OPENSSL_STATIC=1 and
OPENSSL_DIR=<scoped Android crypto install>. Native Android libsodium.a is aliased
to liblibsodium.a for the pinned Windows-host build script's emitted name. The host
hbb_common build dependency needs its separate genuine MSVC libsodium.lib; never
link that library into Android.

Some pinned scripts append installed to VCPKG_ROOT. Give them a private physical
directory with installed/arm64-android, copied from the verified dependency build.
Do not retarget the Windows vcpkg installed junction. A minimal Rust static opus probe
on this host passes with the physical directory but fails through its junction.

Refresh only magnum-opus's scoped Android derived output after changing VCPKG_ROOT;
its pinned build script does not track that environment variable. This removed
25.4MiB of regenerable build cache, not application/user data.

## Commands and acceptance gates

Build with cargo ndk --platform 21 --target aarch64-linux-android build --locked
--release --features flutter,hwcodec --lib, adding the scoped paths config above.
No software-update feature; immutable native policy remains the updater gate.
Use the newly built liblibrustdesk.so as JNI librustdesk.so and package the pinned
NDK libc++_shared.so. Check SHA256 before/after copying; never use upstream's old .so.
Flutter build apk --release --no-pub --target-platform android-arm64 --split-per-abi
--build-name 1.3.3 --build-number 78 --android-project-arg=subnetdeskHelperCandidate=true.

Before installing: inspect manifest/package/version/ABI, native ELF alignment and
required exports, camera permission absence, signer fingerprint and archive contents.
Keep the candidate signer private for future candidate upgrades. Supply corresponding
app/submodule/generated bridge source plus pinned codec source/patch and reproducible
build notes, excluding all private signing material. Install only the helper package
beside the official package. Build success is not paired screen/voice/buzzer/ring or
camera-denial acceptance. Windows Firewall permission remains a human-handled gate.

Keystore credentials, three access modes and reconnect chat-memory cleanup are
already authorized but remain separate pending feature work.
