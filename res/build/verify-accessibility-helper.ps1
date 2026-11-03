param([string]$Version = '1.4.7', [int]$Build = 125)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.OpenDatabase((Join-Path $project "output\SubnetDesk-Helper-$Version-build$Build-Windows-x64.msi"), 0)
function Query-Msi([string]$sql, [int]$columns) {
    $view = $db.OpenView($sql)
    $null = $view.Execute()
    $record = $view.Fetch()
    if ($null -eq $record) { throw "Missing MSI row: $sql" }
    $fields = @()
    for ($i = 1; $i -le $columns; $i++) { $fields += $record.StringData($i) }
    return ,$fields
}
$msiVersion = Query-Msi 'SELECT `Value` FROM `Property` WHERE `Property` = ''ProductVersion''' 1
if ($msiVersion[0] -ne "$Version.$Build") { throw 'MSI version mismatch' }
$reset = Query-Msi 'SELECT `Target` FROM `CustomAction` WHERE `Action` = ''ResetReceiverOnlyForInstall''' 1
if ($reset[0] -ne '--reset-receiver-only-for-install') { throw 'Receiver reset command missing' }
$sequence = Query-Msi 'SELECT `Condition`, `Sequence` FROM `InstallExecuteSequence` WHERE `Action` = ''ResetReceiverOnlyForInstall''' 2
$service = Query-Msi 'SELECT `Sequence` FROM `InstallExecuteSequence` WHERE `Action` = ''CreateStartService''' 1
if (($sequence[0] -replace '\s', '') -ne 'NOT(REMOVE="ALL")' -or [int]$sequence[1] -ge [int]$service[0]) {
    throw 'Receiver reset scheduling mismatch'
}
foreach ($name in @('flutter_windows.dll', 'librustdesk.dll', 'SubnetDesk.exe')) {
    $view = $db.OpenView('SELECT `File`, `FileName` FROM `File`')
    $null = $view.Execute()
    $fileId = $null
    while ($null -ne ($row = $view.Fetch())) {
        if (($row.StringData(2) -split '\|')[-1] -eq $name) {
            $fileId = $row.StringData(1)
            break
        }
    }
    if (!$fileId) { throw "Missing MSI file: $name" }
    $payload = Join-Path $project "output\helper-$Version-build$Build-payload-check\$fileId"
    $expected = Join-Path $project "output\SubnetDesk-Helper-bundle-$Version-build$Build\$name"
    if ((Get-FileHash -LiteralPath $payload).Hash -ne (Get-FileHash -LiteralPath $expected).Hash) {
        throw "Payload hash mismatch: $name"
    }
    Write-Output "PASS: MSI payload $name matches validated bundle."
}
Write-Output "PASS: MSI $Version.$Build resets Receiver-only for all install operations before service startup."
