# Private helper MSI

WiX 4.0.5 and WixToolset.UI.wixext 4.0.5 build an English, x64 MSI from
the verified portable release folder. Builds85/86 retain per-user authoring;
build87+ uses Package-machine.wxs, per-machine Program Files installation,
Administrator elevation and common Start menu/Desktop shortcuts. Windows87 is
1.3.8; Android retains1.3.7/build85 (no Android UI/wire change is needed).

Run build.ps1 with BundlePath, new OutputPath and WorkPath, WixPath and
UiExtensionPath. The source license is rendered into a generated RTF. Payload XML
is generated from all runtime/license files, with deterministic component IDs and
HKCU key paths for old user builds or HKLM installer-only key paths for machine
builds. Component GUID namespaces and UpgradeCodes are distinct across contexts.
Work/output directories must not already exist.

Compilation is followed by explicit Windows Installer ICE validation; check diagnostic
text as well as exit code. Empty installation directories get uninstall cleanup entries
(no recursive/wildcard file deletion). Neutral font asset language metadata does not
register fonts with Windows. ICE91's intentional per-user-only warning is accepted;
build86 additionally permits only the exact ICE61 equal-public-version diagnostic
and verifies the inclusive Upgrade table flag. All errors and other ICE warnings fail.
Machine87+ permits no ICE warnings except the exact ICE61 diagnostic for the scoped
1.4.0/build96 same-version corrective respin. validate.ps1 can validate an existing
MSI without rebuilding or installing it.
Readonly verification extracts every
MSI payload file using 7-Zip and compares hashes with the version-checked staged bundle.

Old85/86 installs to LocalAppData\Programs\SubnetDeskHelper with Start shortcut;
87+ installs to ProgramFiles64Folder\SubnetDesk with Start and Desktop shortcuts.
Uses an independent UpgradeCode, not the upstream product. Machine builds install and
start the `SubnetDesk` Windows service with automatic startup, and register
`SubnetDesk.exe --tray` to launch at user sign-in. Closing the main
window hides it; the notification-area menu remains the explicit Open/Quit control.
The only custom action
is WiX's user-clicked license Print button; it is absent from the install execution
sequence. No firewall, process termination, driver registration, updater, or
post-install app-launch action.
Uninstall removes owned installer files/markers/shortcut, not application config.
Close a running helper yourself before upgrading. This MSI does not replace a
portable running helper. Normal Windows Installer in-use-file prompts remain.

Same-public-version upgrades are enabled so 1.3.7/build85 can upgrade to build86.
The same narrow exception applies to the 1.4.0/build96 background-service corrective
respin, allowing it to replace the earlier 1.4.0 MSI in place. Other machine releases
use normal higher-public-version detection.
Windows Installer compares only the public three-part ProductVersion, not
HELPER_BUILD. Consequently it cannot prevent rollback between private builds of
the same public version: do not reinstall build85 over build86. Higher public
versions retain the normal major-upgrade downgrade gate.
See https://docs.firegiant.com/wix/schema/wxs/majorupgrade/ (AllowSameVersionUpgrades).

Migration86 per-user ->87 machine is NOT an automatic major upgrade: Windows
Installer cannot upgrade across contexts. Close the old helper, uninstall only
the previous private SubnetDesk Helper from Settings > Apps, then run the new MSI
and approve Windows' Administrator prompt yourself. App configuration is not an
installer-owned target and is preserved. The new package detects the old HKCU
installer marker and blocks fresh installation with an English instruction.
Detection is for the installation user's HKCU, not every Windows profile;
other users must remove their own old private Helper separately. No silent
uninstaller, process killer or bypass of UAC is included.
Source: https://learn.microsoft.com/en-us/windows/win32/msi/major-upgrades

Elevation is for installation only: the app retains its normal runtime manifest.
No receiver auto-approval, file-access grant, firewall/service or security settings
are enabled by the installer. Elevated/policy-managed installation can omit a
visible UAC prompt; metadata verifies required privileges, not a physical dialog.

Windows signing certificate is not supplied: MSI is unsigned. Android continues
to use the existing private helper signer. Do not include signing keys in archives.

Runtime prerequisite: the inherited WindowInjection.dll imports MSVCP140.dll,
VCRUNTIME140.dll and VCRUNTIME140_1.dll. Microsoft Visual C++ x64 runtime must already
be installed for that component; this MSI does not run a system redistributable
installer. The target laptop has those runtime DLLs. Other machines must be checked
separately; compilation/extraction is not a clean-machine installation test.
