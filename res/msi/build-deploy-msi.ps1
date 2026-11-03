param(
    [Parameter(Mandatory = $true)][string]$DeployBundlePath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$WorkPath,
    [Parameter(Mandatory = $true)][string]$WixPath,
    [Parameter(Mandatory = $true)][string]$Version
)

$ErrorActionPreference = 'Stop'
$deployBundle = (Resolve-Path -LiteralPath $DeployBundlePath).Path
$wix = (Resolve-Path -LiteralPath $WixPath).Path
$generator = Join-Path $PSScriptRoot 'Deploy\generate_payload.ps1'
$packageSource = Join-Path $PSScriptRoot 'Deploy\Package.wxs'
$work = [IO.Path]::GetFullPath($WorkPath)
$output = [IO.Path]::GetFullPath($OutputPath)

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'Version must use MSI-compatible major.minor.patch format, for example 1.4.3.'
}
if (Test-Path -LiteralPath $output) {
    throw "Output already exists; choose a new path to preserve existing packages: $output"
}
New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($output)) | Out-Null

$deployExe = Join-Path $deployBundle 'SubnetDeskDeploy.exe'
if (-not (Test-Path -LiteralPath $deployExe -PathType Leaf)) { $deployExe = Join-Path $deployBundle 'SubnetDesk.exe' }
if (-not (Test-Path -LiteralPath $deployExe -PathType Leaf)) {
    throw "Deploy bundle is missing its executable: $deployBundle"
}
if (-not (Test-Path -LiteralPath $work)) {
    New-Item -ItemType Directory -Path $work | Out-Null
}
$payloadWxs = Join-Path $work 'DeployPayload.wxs'
& $generator -BundlePath $deployBundle -OutputPath $payloadWxs

$wixArgs = @(
    'build', $packageSource, $payloadWxs,
    '-arch', 'x64',
    '-d', "Version=$Version",
    '-d', "DeployIconPath=$deployExe",
    '-out', $output
)
& $wix @wixArgs
if ($LASTEXITCODE -ne 0) { throw 'Deploy MSI build failed.' }
& $wix msi validate $output *> "$output.validation.log"
if ($LASTEXITCODE -ne 0) { throw "Deploy MSI validation failed: $output.validation.log" }
Write-Output "Created $output"
