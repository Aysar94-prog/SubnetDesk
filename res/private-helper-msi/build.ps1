param(
    [Parameter(Mandatory=$true)][string]$BundlePath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$WorkPath,
    [Parameter(Mandatory=$true)][string]$WixPath,
    [Parameter(Mandatory=$true)][string]$UiExtensionPath,
    [string]$ReleaseVersion = '1.3.7', [int]$ReleaseBuild = 85
)
$ErrorActionPreference = 'Stop'
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
    $taskHex = (StableId ('SubnetDeskPrivateHelper:component:' + $path)).Substring(1).ToLowerInvariant()
    $taskHex = $taskHex.Substring(0,12) + '5' + $taskHex.Substring(13,3) + '8' + $taskHex.Substring(17)
    ([guid]$taskHex).ToString()
}
$taskXml = [Text.StringBuilder]::new()
[void]$taskXml.AppendLine('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"><Fragment>')
$taskDirectories = @{ '' = 'INSTALLFOLDER' }
$taskFiles = @(Get-ChildItem -LiteralPath $taskBundle -Recurse -File | Sort-Object FullName)
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
    # HKCU key paths are required for a per-user component. Each path has a
    # stable identifier; no user configuration or OS-wide registry is modified.
    [void]$taskXml.AppendLine('<DirectoryRef Id="' + $taskDirectories[$taskParent] + '"><Component Id="C' + $taskId + '" Guid="' + (StableGuid $taskRelative) + '">')
    [void]$taskXml.AppendLine('<File Id="F' + $taskId + '" Source="' + (XmlText $taskFile.FullName) + '" Name="' + (XmlText $taskFile.Name) + '" />')
    [void]$taskXml.AppendLine('<RegistryValue Root="HKCU" Key="Software\SubnetDeskPrivate\HelperInstaller\Files" Name="' + $taskId + '" Type="integer" Value="1" KeyPath="yes" /></Component></DirectoryRef>')
}
[void]$taskXml.AppendLine('<ComponentGroup Id="HelperPayload">')
foreach ($taskFile in $taskFiles) {
    [void]$taskXml.AppendLine('<ComponentRef Id="C' + (StableId ('file:' + $taskFile.FullName.Substring($taskBundle.Length+1))) + '" />')
}
[void]$taskXml.AppendLine('</ComponentGroup></Fragment></Wix>')
# These are generated compiler inputs, not maintained application source.
[IO.File]::WriteAllText("$WorkPath\Payload.wxs", $taskXml.ToString(), [Text.UTF8Encoding]::new($false))
$taskLicense = [IO.File]::ReadAllText("$taskBundle\LICENSE-AGPL-3.0.txt")
$taskLicense = $taskLicense.Replace('\','\\').Replace('{','\{').Replace('}','\}').Replace("`r",'').Replace("`n",'\par ')
[IO.File]::WriteAllText("$WorkPath\License.rtf", '{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs16 ' + $taskLicense + '}', [Text.Encoding]::ASCII)
& $WixPath build "$PSScriptRoot\Package.wxs" "$WorkPath\Payload.wxs" -arch x64 -culture en-us -ext $UiExtensionPath -d "ReleaseVersion=$ReleaseVersion" -d "ReleaseBuild=$ReleaseBuild" -d "LicenseRtf=$WorkPath\License.rtf" -out $OutputPath -intermediatefolder "$WorkPath\obj" -pdbtype none
if ($LASTEXITCODE -ne 0) { throw 'Private MSI compilation/validation failed.' }
Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256
