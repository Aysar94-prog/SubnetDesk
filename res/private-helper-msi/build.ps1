param(
    [Parameter(Mandatory=$true)][string]$BundlePath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$WorkPath,
    [Parameter(Mandatory=$true)][string]$WixPath,
    [Parameter(Mandatory=$true)][string]$UiExtensionPath,
    [string]$ReleaseVersion = '1.3.7', [int]$ReleaseBuild = 85
)
$ErrorActionPreference = 'Stop'
$taskMachine = $ReleaseBuild -ge 87
$taskRegistryRoot = if ($taskMachine) { 'HKLM' } else { 'HKCU' }
$taskRegistryKey = if ($taskMachine) { 'Software\SubnetDeskPrivate\HelperMachineInstaller' } else { 'Software\SubnetDeskPrivate\HelperInstaller' }
$taskBundle = (Resolve-Path -LiteralPath $BundlePath).Path.TrimEnd('\')
if ((Get-Item "$taskBundle\SubnetDesk.exe").VersionInfo.FileVersion -ne "$ReleaseVersion+$ReleaseBuild") {
    throw 'MSI payload version differs from requested release.'
}
if (Test-Path -LiteralPath $OutputPath) { throw 'Preserve existing MSI; choose a new output.' }
if (Test-Path -LiteralPath $WorkPath) { throw 'Preserve existing MSI work directory.' }
New-Item -ItemType Directory -Path $WorkPath | Out-Null
function XmlText([string]$text) { [Security.SecurityElement]::Escape($text) }
function StableId([string]$path) {
    $taskSha = [Security.Cryptography.SHA256]::Create()
    try { $taskBytes = $taskSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($path.ToLowerInvariant())) }
    finally { $taskSha.Dispose() }
    'P' + ([BitConverter]::ToString($taskBytes).Replace('-','').Substring(0,32))
}
function StableGuid([string]$path) {
    $taskNamespace = if ($taskMachine) { 'SubnetDeskPrivateHelperMachine:component:' } else { 'SubnetDeskPrivateHelper:component:' }
    $taskHex = (StableId ($taskNamespace + $path)).Substring(1).ToLowerInvariant()
    $taskHex = $taskHex.Substring(0,12) + '5' + $taskHex.Substring(13,3) + '8' + $taskHex.Substring(17)
    ([guid]$taskHex).ToString()
}
$taskXml = [Text.StringBuilder]::new()
[void]$taskXml.AppendLine('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"><Fragment>')
$taskDirectories = @{ '' = 'INSTALLFOLDER' }
$taskFiles = @(Get-ChildItem -LiteralPath $taskBundle -Recurse -File | Sort-Object FullName)
$taskInstaller = New-Object -ComObject WindowsInstaller.Installer
foreach ($taskFile in $taskFiles) {
    $taskRelative = $taskFile.FullName.Substring($taskBundle.Length+1)
    if ($taskRelative -match '(?i)(^|\\)(\.private|\.git|signing)(\\|$)|\.(pfx|jks|keystore|pdb)$') { throw 'Private/debug material in MSI input.' }
    $taskParent = Split-Path $taskRelative -Parent
    $taskParts = @($taskParent -split '\\' | Where-Object { $_ })
    $taskCurrent = ''
    foreach ($taskPart in $taskParts) {
        $taskNext = if ($taskCurrent) { "$taskCurrent\$taskPart" } else { $taskPart }
        if (-not $taskDirectories.ContainsKey($taskNext)) {
            $taskDirId = StableId "dir:$taskNext"
            [void]$taskXml.AppendLine('<DirectoryRef Id="' + $taskDirectories[$taskCurrent] + '"><Directory Id="' + $taskDirId + '" Name="' + (XmlText $taskPart) + '" /></DirectoryRef>')
            $taskDirectories[$taskNext] = $taskDirId
        }
        $taskCurrent = $taskNext
    }
    $taskId = StableId "file:$taskRelative"
    # Installer-owned markers only; machine and user products have distinct identities.
    [void]$taskXml.AppendLine('<DirectoryRef Id="' + $taskDirectories[$taskParent] + '"><Component Id="C' + $taskId + '" Guid="' + (StableGuid $taskRelative) + '">')
    $taskLanguage = if ($taskInstaller.FileVersion($taskFile.FullName, $false) -and -not $taskInstaller.FileVersion($taskFile.FullName, $true)) { ' DefaultLanguage="0"' } else { '' }
    $taskShortcutExe = $taskMachine -and $taskRelative -eq 'SubnetDesk.exe'
    if ($taskShortcutExe) {
        # Advertised shortcuts belong to the actual EXE/file key path, avoiding
        # per-user shortcut key paths in an all-users machine installation.
        [void]$taskXml.AppendLine('<File Id="F' + $taskId + '" Source="' + (XmlText $taskFile.FullName) + '" Name="SubnetDesk.exe" KeyPath="yes">')
        foreach ($taskShortcut in @(@('HelperStart','HelperMenu'), @('HelperDesktop','DesktopFolder'))) {
            [void]$taskXml.AppendLine('<Shortcut Id="' + $taskShortcut[0] + '" Directory="' + $taskShortcut[1] + '" Name="SubnetDesk Helper" Advertise="yes" WorkingDirectory="INSTALLFOLDER" Description="Open SubnetDesk Helper" />')
        }
        [void]$taskXml.AppendLine('</File>')
    } else {
        [void]$taskXml.AppendLine('<File Id="F' + $taskId + '" Source="' + (XmlText $taskFile.FullName) + '" Name="' + (XmlText $taskFile.Name) + '"' + $taskLanguage + ' />')
    }
    $taskRegistryKeyPath = if ($taskShortcutExe) { 'no' } else { 'yes' }
    [void]$taskXml.AppendLine('<RegistryValue Root="' + $taskRegistryRoot + '" Key="' + $taskRegistryKey + '\Files" Name="' + $taskId + '" Type="integer" Value="1" KeyPath="' + $taskRegistryKeyPath + '" /></Component></DirectoryRef>')
}
[void]$taskXml.AppendLine('<DirectoryRef Id="INSTALLFOLDER"><Component Id="HelperFolders" Guid="' + (StableGuid ':folders') + '">')
$taskCleanupDirectories = @($taskDirectories.Values)
if (-not $taskMachine) { $taskCleanupDirectories += 'HelperPrograms' }
else { $taskCleanupDirectories += 'HelperMenu' }
foreach ($taskDirectory in $taskCleanupDirectories) {
    [void]$taskXml.AppendLine('<RemoveFolder Id="R' + $taskDirectory + '" Directory="' + $taskDirectory + '" On="uninstall" />')
}
[void]$taskXml.AppendLine('<RegistryValue Root="' + $taskRegistryRoot + '" Key="' + $taskRegistryKey + '" Name="Folders" Type="integer" Value="1" KeyPath="yes" /></Component></DirectoryRef>')
[void]$taskXml.AppendLine('<ComponentGroup Id="HelperPayload"><ComponentRef Id="HelperFolders" />')
foreach ($taskFile in $taskFiles) {
    [void]$taskXml.AppendLine('<ComponentRef Id="C' + (StableId ('file:' + $taskFile.FullName.Substring($taskBundle.Length+1))) + '" />')
}
[void]$taskXml.AppendLine('</ComponentGroup></Fragment></Wix>')
# These are generated compiler inputs, not maintained application source.
[IO.File]::WriteAllText("$WorkPath\Payload.wxs", $taskXml.ToString(), [Text.UTF8Encoding]::new($false))
$taskLicense = [IO.File]::ReadAllText("$taskBundle\LICENSE-AGPL-3.0.txt")
$taskLicense = $taskLicense.Replace('\','\\').Replace('{','\{').Replace('}','\}').Replace("`r",'').Replace("`n",'\par ')
[IO.File]::WriteAllText("$WorkPath\License.rtf", '{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs16 ' + $taskLicense + '}', [Text.Encoding]::ASCII)
$taskSameVersion = if ($ReleaseVersion -eq '1.3.7' -and $ReleaseBuild -eq 86) { 'yes' } else { 'no' }
$taskAuthoring = if ($taskMachine) { "$PSScriptRoot\Package-machine.wxs" } else { "$PSScriptRoot\Package.wxs" }
& $WixPath build $taskAuthoring "$WorkPath\Payload.wxs" -arch x64 -culture en-us -ext $UiExtensionPath -d "ReleaseVersion=$ReleaseVersion" -d "ReleaseBuild=$ReleaseBuild" -d "AllowSameVersionUpgrades=$taskSameVersion" -d "LicenseRtf=$WorkPath\License.rtf" -out $OutputPath -intermediatefolder "$WorkPath\obj" -pdbtype none
if ($LASTEXITCODE -ne 0) { throw 'Private MSI compilation/validation failed.' }
# Explicit Windows Installer ICE validation is separate from WiX compilation.
& "$PSScriptRoot\validate.ps1" -MsiPath $OutputPath -WixPath $WixPath -LogPath "$WorkPath\ice-validation.log" -ReleaseVersion $ReleaseVersion -ReleaseBuild $ReleaseBuild
Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256
