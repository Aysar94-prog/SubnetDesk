# Private helper MSI

WiX 4.0.5 and WixToolset.UI.wixext 4.0.5 build an English, x64, per-user MSI from
the verified portable release folder. Package version matches Android versionName;
HELPER_BUILD matches the logical build (Android versionCode remains upgrade-safe).

Run build.ps1 with BundlePath, new OutputPath and WorkPath, WixPath and
UiExtensionPath. The source license is rendered into a generated RTF. Payload XML
is generated from all runtime/license files, with deterministic component IDs and
HKCU key paths. Work/output directories must not already exist.

Installs to LocalAppData\Programs\SubnetDeskHelper and adds a Start menu shortcut.
Uses an independent UpgradeCode, not the upstream product. No service, firewall,
process termination, driver registration, autorun, updater, or app-launch action.
Uninstall removes owned installer files/markers/shortcut, not application config.
Close a running helper yourself before upgrading. This MSI does not replace a
portable running helper. Normal Windows Installer in-use-file prompts remain.

Windows signing certificate is not supplied: MSI is unsigned. Android continues
to use the existing private helper signer. Do not include signing keys in archives.
