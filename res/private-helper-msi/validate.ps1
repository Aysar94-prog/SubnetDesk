param(
    [Parameter(Mandatory=$true)][string]$MsiPath,
    [Parameter(Mandatory=$true)][string]$WixPath,
    [Parameter(Mandatory=$true)][string]$LogPath,
    [string]$ReleaseVersion = '1.3.7', [int]$ReleaseBuild = 85
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $LogPath) { throw 'Preserve existing validation log.' }
# Some CLI versions emit ICE errors with exit code zero; inspect both.
$taskValidation = & $WixPath msi validate $MsiPath 2>&1
$taskExitCode = $LASTEXITCODE
# A successful machine package can emit no diagnostics: still create evidence.
Set-Content -LiteralPath $LogPath -Value @("ExitCode=$taskExitCode", "DiagnosticCount=$(@($taskValidation).Count)", $taskValidation) -Encoding utf8
if ($taskExitCode -ne 0 -or ($taskValidation -match 'error WIX|error ICE')) {
    throw 'Windows Installer ICE validation failed.'
}
$taskSameVersionWarning = 'warning WIX1076: ICE61: This product should remove only older versions of itself. The Maximum version is not less than the current product. (' + $ReleaseVersion + ' ' + $ReleaseVersion + ')'
foreach ($taskDiagnostic in $taskValidation) {
    $taskLine = [string]$taskDiagnostic
    if ($taskLine -notmatch 'warning WIX') { continue }
    if ($ReleaseBuild -lt 87 -and $taskLine -match 'warning WIX1076: ICE91:') { continue }
    # Allow only this exact, intentional equal-public-version warning. All other
    # ICE61 diagnostics fail. verify.ps1 additionally checks Upgrade table flags.
    if ($ReleaseVersion -eq '1.3.7' -and $ReleaseBuild -eq 86 -and $taskLine.EndsWith($taskSameVersionWarning)) { continue }
    throw "Unexpected MSI validation warning: $taskLine"
}
Write-Output 'Explicit MSI ICE validation PASS: zero errors; machine builds permit no ICE warnings.'
