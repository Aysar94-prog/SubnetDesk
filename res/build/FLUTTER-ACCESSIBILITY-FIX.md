# Windows accessibility crash repair

Build124 repairs the Flutter 3.44.1 engine crash at RVA `0x3e735`, symbolicated
with its matching SDK PDB as `FlutterPlatformNodeDelegate::ChildAtIndex`, line
90. Windows Application events on 2026-11-02 recorded `c0000005` followed by
`c000041d` at this address. Upstream: flutter/flutter#195399.

`GetUnignoredChildAtIndex` can return null while an accessibility client queries
a changing tree. The original engine immediately reads `child->id()`. The
repair returns a null accessible object for a missing child or expired bridge;
valid children retain their existing behavior and shared-pointer cleanup.

The source equivalent is `flutter-accessibility.patch`. This workspace has the
Flutter engine sources and PDB, but not the engine's full build dependencies.
For this release, `patch_flutter_accessibility.py` applies an equivalent native
guard to the staged **prebuilt engine**, not to the SDK or installed program.
It only accepts SHA256
`a147927018fcc1a843fb3938ead58838d2e185ce7d840bc4191a7a1b90c21015`;
it refuses all other engines, signed binaries, unexpected instruction bytes and
occupied section-header space. It adds an RX section, an unwind entry, and a
manifest with input/output hashes. No accessibility features are disabled.
Replace this compatibility patch with a source-built/upstream-fixed engine
when one is available; do not adjust its hash/offsets for a different engine.

Validation:

```powershell
python res/build/test_flutter_accessibility.py -v
python res/build/test_flutter_accessibility_engine.py <original-engine.dll> <new-test-directory>
```

The first test executes the actual guard machine code for null and valid
inputs. The second loads the patched engine itself and exercises 4000 absent
child queries and 1000 successful child queries, validates shared-pointer
counts, and checks Windows can find its unwind metadata. Run the integration
test in a separate process because a native regression can terminate it.

`build-accessibility-helper.ps1` defaults to Helper 1.4.7 Build125. Version 1.4.6
uses the validated Build123 Rust backend; later versions require a manifest of
the freshly rebuilt native DLL with its version, build and SHA256 before
packaging. Both paths retain the patched engine and validated installer policy.
Candidates and test engines stay in `output/`; promote only validated release
artifacts with the release-output-rotation publisher.
