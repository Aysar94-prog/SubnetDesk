# SubnetDesk MSI project

Use Visual Studio 2022 to compile this project.

This project is mainly derived from <https://github.com/MediaPortal/MediaPortal-2.git> .

## Separate Helper and deployment packages

Build and release two independent Windows Installer products:

- `SubnetDesk-Helper.msi` installs the Helper application/service on its own machine. It owns unattended-access setup and its normal MSI install, repair, major upgrade, and uninstall lifecycle. It contains no remote deployment entry point or deployment screen.
- `SubnetDesk-Deploy.msi` installs the remote deployment utility in its own Program Files directory and Start Menu group. It lets the administrator browse for a Helper MSI version, collects remote administrator credentials in the deployment UI, copies and silently installs the Helper MSI over PowerShell Remoting, and verifies the target service. Its UpgradeCode is distinct from the Helper product's UpgradeCode.

The deployment UI is available only in a build compiled with `--dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=true`. Build two release bundles sequentially from `flutter\` and copy each release output before starting the next build:

```powershell
$tools = 'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools'
$env:CARGO_HOME = Join-Path $tools 'cargo'
$env:RUSTUP_HOME = Join-Path $tools 'rustup'
$env:PUB_CACHE = Join-Path $tools 'pub-cache'
$env:VCPKG_ROOT = Join-Path $tools 'vcpkg'
$env:VCPKG_INSTALLED_ROOT = Join-Path $tools 'native-installed'
$env:LIBCLANG_PATH = Join-Path $tools 'llvm\bin'
$flutter = Join-Path $tools 'flutter\bin\flutter.bat'
& $flutter build windows --release --dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=false
Copy-Item -Recurse '.\build\windows\x64\runner\Release' '..\output\SubnetDesk-Helper-bundle'
& $flutter build windows --release --dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=true
Copy-Item -Recurse '.\build\windows\x64\runner\Release' '..\output\SubnetDesk-Deploy-bundle'
```

The first bundle is the only payload for `SubnetDesk-Helper.msi`; the second is the deployment utility payload. The compile-time split keeps the remote deployment route/page out of the Helper executable. Build the Helper MSI with the existing `Package` WiX project and output it as `SubnetDesk-Helper.msi`.

After building the deployment utility bundle, package the Deploy MSI with the bundled WiX 4 executable:

```powershell
& '.\res\msi\build-deploy-msi.ps1' `
  -DeployBundlePath '.\output\SubnetDesk-Deploy-bundle' `
  -OutputPath '.\output\SubnetDesk-Deploy.msi' `
  -WorkPath '.\output\deploy-msi-work' `
  -WixPath 'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools\wix4\wix.exe' `
  -Version '1.4.3'
```

Choose a new output path for each build; the script refuses to overwrite an existing MSI. The Helper MSI continues to be built from the existing `Package` WiX project, using the Helper-flavored Flutter bundle as its payload and an output filename of `SubnetDesk-Helper.msi`.

## Steps

1. `python preprocess.py`, see `python preprocess.py -h` for help.
2. Build the .sln solution.

Run `msiexec /i package.msi /l*v install.log` to record the log.

## Usage

1. Put the custom dialog bitmaps in "Resources" directory. The supported bitmaps are `['WixUIBannerBmp', 'WixUIDialogBmp', 'WixUIExclamationIco', 'WixUIInfoIco', 'WixUINewIco', 'WixUIUpIco']`.

## Knowledge

### properties

[wix-toolset-set-custom-action-run-only-on-uninstall](https://www.advancedinstaller.com/versus/wix-toolset/wix-toolset-set-custom-action-run-only-on-uninstall.html)

| Property Name | Install | Uninstall | Change | Repair | Upgrade |
| ------ | ------ | ------ | ------ | ------ | ------ |
| Installed | False | True | True | True | True |
| REINSTALL | False | False | False | True | False |
| UPGRADINGPRODUCTCODE | False | False | False | False | True |
| REMOVE | False | True | False | False | True |

## TODOs

1. Start menu. Uninstall
1. custom options
1. Custom client.
    1. firewall and tcp allow. Outgoing
    1. Show license ?
    1. Do create service. Outgoing.

## Refs

1. [windows-installer-portal](https://learn.microsoft.com/en-us/windows/win32/Msi/windows-installer-portal)
1. [wxs](https://wixtoolset.org/docs/schema/wxs/)
1. [wxs github](https://github.com/wixtoolset/wix)

Helper installations use a new protected installation profile ID on a fresh install or major upgrade. Repair retains that ID. Existing profiles are kept on disk, while old options and recent connections are excluded from the new installation. Explicit unlock persists within that installation. Deploy uses the selected MSI, validates its product/version/hash, and verifies that product version remotely. Bulk deployment accepts large lists, including 600 devices, with administrator-selected concurrency and can stop pending devices.

## Build both Windows installers with native compilation

Run `res\msi\build-windows-installers.ps1 -Version 1.4.4 -Build 104` from the repository root. This imports Visual Studio, uses the bundled Cargo/Flutter/WiX toolchain, builds Rust before Flutter, checks DLL hashes, and creates both independent MSIs. Choose a new build number/output path for another release.

Run the focused Flutter tests in `flutter/test/receiver_only_settings_test.dart` and `flutter/test/remote_helper_deployment_test.dart`. Set `HELPER_MSI_TEST_PATH` and `DEPLOY_MSI_TEST_PATH` to exercise metadata validation against the built installers. Bulk scheduling tests cover 600 devices without requiring live targets.
