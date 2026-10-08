# Local Windows helper build checkpoint

## Current runner repair: 2026-10-08

User authorized implementation after the first candidate failed live incoming dock acceptance.
Native runner argument trim now preserves the final character and handles empty arguments.
Native production-header regression: old0/17 -> fixed17/17; launch policy2/2 rechecked.
Rust package1.3.1, Flutter1.3.1+76: local test candidate, not official upstream1.3.1.
Full rebuild completed: Rust release exit0 (46 existing warnings), Flutter Release exit0,
Flutter53/53; CTest1/1 and launch policy2/2. Reproducible local orchestration is
`D:\LAN-Messenger\outputs\SubnetDesk-helper-cm\checks\build-runner-fix.ps1`.
It imports MSVC2022 environment in-process, checks/maps unused S:, builds Rust with locked
dependencies and original full features, builds Flutter with --no-pub and explicit version,
runs Flutter tests, and removes only its own validated S: mapping. No global PATH change.
Native test-only mode: `-NativeTestsOnly`. Portable CMake/CTest instructions are under
flutter/windows/runner/tests/README.md. Keep native runtime acceptance separate from tests.
Original installed service is now Stopped/Auto with explicit user approval; installed files
remain untouched. New1.3.1+76 candidate switched in at09:47:38/PID4052 and owns TCP21118.
Direct --cm reaches Flutter CM initialization instead of immediate exit1. With no session,
it later closes consistent with existing6s idle policy. Actual incoming dock acceptance remains
pending user reconnect; native startup is not visual/session acceptance. Reboot may restore
old installed service. Final staging renames upstream-built rustdesk.exe to SubnetDesk.exe,
copies original auxiliary resources without installing drivers, and checks rebuilt DLL hashes.
Older build observations below are historical.

Source changes are Windows-only and committed locally; the 2026-10-08 candidate is fully built
but not accepted against a real session. Do not replace the installed
SubnetDesk without user direction. Do not combine this application
with LAN Messenger or use its Android signing key.

## Existing environment

- Source: `D:\LAN-Messenger\reference\SubnetDesk-v1.3.0\source\zibo-chen-SubnetDesk-1d3ac5a`.
- Tools: `D:\LAN-Messenger\reference\SubnetDesk-v1.3.0\tools`, mapped as `S:`.
- Scoped Cargo/Rustup paths: `S:\cargo`, `S:\rustup`.
- PUB_CACHE: `D:\LAN-Messenger\reference\SubnetDesk-v1.3.0\tools\pub-cache`.
- VCPKG_ROOT: `S:\vcpkg`; VCPKG_INSTALLED_ROOT: `S:\native-installed`.
  `vcpkg/installed` junction also points at native-installed for upstream magnum-opus.
- LIBCLANG_PATH: `S:\llvm\bin`.
- Rust 1.82.0, Flutter 3.44.1/Dart 3.12.1, FRB codegen 1.80.1, LLVM 15.0.6.
- Original exact hbb_common submodule is initialized and unchanged.

If `S:` is absent after restart, recreate it only after confirming the drive is unused.
Never remap an existing user drive. Environment variables are per-build, not global changes.

## Build ordering

1. Finish the manifest native install at pinned baseline
   `120deac3062162151622ca4860575a33844ba10b`:
   `S:\vcpkg\vcpkg.exe install --triplet x64-windows-static --host-triplet x64-windows-static
   --x-manifest-root=<source> --x-install-root=S:\native-installed --disable-metrics`.
2. Generated Rust/Dart bridge already exists locally and is Git-ignored. If regeneration is
   needed, use the upstream bridge workflow's command with `--llvm-path S:\llvm`,
   `--skip-add-mod-to-lib` and RUST_LOG=info. It runs build_runner; wait until successful
   before compiling tests or Flutter. Do not change FFI signatures for this UI work.
3. Use the MSVC 2022 developer environment. Rust library: from source, with the scoped environment above,
   `cargo build --locked --features flutter,software-update,hwcodec,vram --lib --release`.
   Full native headers/libraries must exist first; missing opus/FFmpeg errors before that
   are expected dependency failures, not completed source verification.
4. Flutter: from source/flutter, `flutter build windows --release --no-pub`.
   Local plugin directory junctions replace unavailable symlinks without changing Developer
   Mode or system security policy. A pub get may recreate their directory; restore validated
   junctions from .flutter-plugins-dependencies if needed.
5. Build the virtual-display DLL: `cargo build -p dylib_virtual_display --locked --release`.
   Copy runner/Release plus target/release/deps/dylib_virtual_display.dll
   as upstream build.py requires to a clearly identified candidate under
   `D:\LAN-Messenger\outputs\SubnetDesk-helper-cm`. Preserve license/notices and provide
   corresponding source (including the pinned submodule) before distribution.
6. WindowInjection is pinned to upstream workflow commit
   `ecd8d6a139eee76845ea66423fb739af450fda90` in tools/window-injection-source. Build its x64
   Release vcxproj with MSBuild 2022, PlatformToolset=v143; retain its MIT license.
   Original USB/printer archives are in tools/bundle-assets; printer checksums match the
   upstream release manifest. Copy resources only; do not install drivers.

## Current evidence / next gates

Full Flutter suite 53/53 and actual launch-policy module tests 2/2 passed.
All 16 native packages, full-feature Rust library, virtual-display DLL, WindowInjection DLL and
Flutter Windows Release builds completed. Earlier missing-DLL assembly failure is resolved.
Candidate CLI startup: 1.3.0, exit 0, isolated data directories.
Full Flutter analysis has no errors; upstream style/deprecation warnings remain.

Use WINDOWS_HELPER_STATUS.md for runtime/device gates. Physical paired Android chat/audio,
service startup and dock DPI/work-area acceptance are still unverified. The original installed
SubnetDesk service is Running/Auto at C:/Program Files/SubnetDesk/SubnetDesk.exe --service.
It was not stopped/replaced and can still launch old/headless CM. Obtain user direction for
a session-safe backend handoff. Do not publish, stop services, install drivers or overwrite
installed applications as an automatic next step.
