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
register fonts with Windows. Only ICE91's intentional per-user-only warning is accepted;
all errors and other ICE warnings fail the build. Readonly verification extracts every
MSI payload file using 7-Zip and compares hashes with the version-checked staged bundle.

Installs to LocalAppData\Programs\SubnetDeskHelper and adds a Start menu shortcut.
Uses an independent UpgradeCode, not the upstream product. The only custom action
is WiX's user-clicked license Print button; it is absent from the install execution
sequence. No service, firewall,
process termination, driver registration, autorun, updater, or app-launch action.
Uninstall removes owned installer files/markers/shortcut, not application config.
Close a running helper yourself before upgrading. This MSI does not replace a
portable running helper. Normal Windows Installer in-use-file prompts remain.

Windows signing certificate is not supplied: MSI is unsigned. Android continues
to use the existing private helper signer. Do not include signing keys in archives.
