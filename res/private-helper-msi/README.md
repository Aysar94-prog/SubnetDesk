# Private helper MSI

WiX 4.0.5 and WixToolset.UI.wixext 4.0.5 build an English, x64, per-user MSI from
the verified portable release folder. Package version matches Android versionName;
HELPER_BUILD matches the logical build (Android versionCode remains upgrade-safe).

Run build.ps1 with BundlePath, new OutputPath and WorkPath, WixPath and
UiExtensionPath. The source license is rendered into a generated RTF. Payload XML
is generated from all runtime/license files, with deterministic component IDs and
HKCU key paths. Work/output directories must not already exist.

Compilation is followed by explicit Windows Installer ICE validation; check diagnostic
text as well as exit code. Empty installation directories get uninstall cleanup entries
(no recursive/wildcard file deletion). Neutral font asset language metadata does not
register fonts with Windows. ICE91's intentional per-user-only warning is accepted;
build86 additionally permits only the exact ICE61 equal-public-version diagnostic
and verifies the inclusive Upgrade table flag. All errors and other ICE warnings fail.
validate.ps1 can validate an existing MSI without rebuilding or installing it.
Readonly verification extracts every
MSI payload file using 7-Zip and compares hashes with the version-checked staged bundle.

Installs to LocalAppData\Programs\SubnetDeskHelper and adds a Start menu shortcut.
Uses an independent UpgradeCode, not the upstream product. The only custom action
is WiX's user-clicked license Print button; it is absent from the install execution
sequence. No service, firewall,
process termination, driver registration, autorun, updater, or app-launch action.
Uninstall removes owned installer files/markers/shortcut, not application config.
Close a running helper yourself before upgrading. This MSI does not replace a
portable running helper. Normal Windows Installer in-use-file prompts remain.

Same-public-version upgrades are enabled so 1.3.7/build85 can upgrade to build86.
Windows Installer compares only the public three-part ProductVersion, not
HELPER_BUILD. Consequently it cannot prevent rollback between private builds of
the same public version: do not reinstall build85 over build86. Higher public
versions retain the normal major-upgrade downgrade gate.
See https://docs.firegiant.com/wix/schema/wxs/majorupgrade/ (AllowSameVersionUpgrades).

Windows signing certificate is not supplied: MSI is unsigned. Android continues
to use the existing private helper signer. Do not include signing keys in archives.

Runtime prerequisite: the inherited WindowInjection.dll imports MSVCP140.dll,
VCRUNTIME140.dll and VCRUNTIME140_1.dll. Microsoft Visual C++ x64 runtime must already
be installed for that component; this per-user MSI does not run a system redistributable
installer. The target laptop has those runtime DLLs. Other machines must be checked
separately; compilation/extraction is not a clean-machine installation test.
