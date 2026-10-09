param(
    [Parameter(Mandatory=$true)][string]$MsiPath,
    [Parameter(Mandatory=$true)][string]$PayloadXml,
    [Parameter(Mandatory=$true)][string]$ExtractPath,
    [string]$SevenZip = '7z.exe',
    [string]$ReleaseVersion = '1.3.7', [int]$ReleaseBuild = 85
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $ExtractPath) { throw 'Preserve existing extraction directory.' }
$taskInstaller = New-Object -ComObject WindowsInstaller.Installer
$taskDatabase = $taskInstaller.OpenDatabase((Resolve-Path -LiteralPath $MsiPath).Path, 0)
$taskSummary = $taskDatabase.SummaryInformation(0)
if ($taskSummary.Property(7) -ne 'x64;1033' -or ([int]$taskSummary.Property(15) -band 8) -eq 0) { throw 'Expected x64 English limited-privilege MSI.' }
function Query([string]$sql, [int]$columns) {
    $taskView = $taskDatabase.OpenView($sql)
    [void]$taskView.Execute()
    try {
        while ($taskRecord = $taskView.Fetch()) {
            $taskRow = @()
            for ($taskIndex = 1; $taskIndex -le $columns; $taskIndex++) { $taskRow += $taskRecord.StringData($taskIndex) }
            ,$taskRow
        }
    } finally { [void]$taskView.Close() }
}
$taskProps = @{}
foreach ($taskRow in @(Query 'SELECT `Property`, `Value` FROM `Property`' 2)) { $taskProps[$taskRow[0]] = $taskRow[1] }
if ($taskProps['ProductVersion'] -ne $ReleaseVersion -or $taskProps['HELPER_BUILD'] -ne "$ReleaseBuild" -or $taskProps['ProductLanguage'] -ne '1033' -or $taskProps['ProductName'] -ne 'SubnetDesk Helper') { throw 'MSI release/English identity mismatch.' }
if ($taskProps['UpgradeCode'] -ne '{76B63726-899A-49A7-95DF-52EF79D7C8C2}' -or $taskProps.ContainsKey('ALLUSERS')) { throw 'MSI private/per-user identity mismatch.' }
$taskDirectories = @{}
foreach ($taskRow in @(Query 'SELECT `Directory`, `Directory_Parent`, `DefaultDir` FROM `Directory`' 3)) { $taskDirectories[$taskRow[0]] = @($taskRow[1], ($taskRow[2] -split '\|')[-1]) }
if ($taskDirectories['INSTALLFOLDER'][0] -ne 'HelperPrograms' -or $taskDirectories['INSTALLFOLDER'][1] -ne 'SubnetDeskHelper' -or $taskDirectories['HelperPrograms'][0] -ne 'LocalAppDataFolder') { throw 'Unexpected install directory.' }
$taskTables = @(Query 'SELECT `Name` FROM `_Tables`' 1 | ForEach-Object { $_[0] })
foreach ($taskForbidden in @('ServiceInstall','ServiceControl','Environment','MoveFiles','RemoveIniFile','IniFile','SelfReg','RemoveRegistry','Font','Class','ProgId','Extension','MIME','TypeLib','ODBCDriver','ODBCDataSource')) {
    if ($taskTables -contains $taskForbidden -and @(Query ('SELECT * FROM `' + $taskForbidden + '`') 1).Count) { throw "Unexpected installer mutation table: $taskForbidden" }
}
if ($taskTables -contains 'CustomAction') {
    foreach ($taskRow in @(Query 'SELECT `Action`, `Type`, `Source`, `Target` FROM `CustomAction`' 4)) {
        # WiX's license Print button is the only permitted custom action; it is
        # user-clicked UI only, never an installation/execution action.
        if (($taskRow -join '|') -ne 'WixUIPrintEula_X64|65|WixUiCa_X64|PrintEula') { throw 'Unexpected MSI custom action.' }
    }
    foreach ($taskRow in @(Query 'SELECT `Action` FROM `InstallExecuteSequence`' 1)) {
        if ($taskRow[0] -like 'WixUI*') { throw 'UI action must never execute during installation.' }
    }
}
foreach ($taskRow in @(Query 'SELECT `Root`, `Key` FROM `Registry`' 2)) {
    if ($taskRow[0] -ne '1' -or $taskRow[1] -notlike 'Software\SubnetDeskPrivate\HelperInstaller*') { throw 'Unexpected installer registry target.' }
}
foreach ($taskRow in @(Query 'SELECT `FileName`, `InstallMode` FROM `RemoveFile`' 2)) {
    if ($taskRow[0] -or $taskRow[1] -ne '2') { throw 'MSI must remove empty owned folders only.' }
}
foreach ($taskRow in @(Query 'SELECT `Name`, `Target` FROM `Shortcut`' 2)) {
    if ($taskRow[0] -notmatch 'SubnetDesk Helper$' -or $taskRow[1] -ne '[INSTALLFOLDER]SubnetDesk.exe') { throw 'Unexpected shortcut.' }
}
New-Item -ItemType Directory -Path $ExtractPath | Out-Null
# 7-Zip exposes the MSI's embedded cabinet directly as its payload file IDs.
& $SevenZip x $MsiPath "-o$ExtractPath\payload" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'MSI embedded payload extraction failed.' }
[xml]$taskPayload = Get-Content -LiteralPath $PayloadXml -Raw
$taskExpected = @($taskPayload.SelectNodes('//*[local-name()="File"]'))
if (@(Query 'SELECT `File` FROM `File`' 1).Count -ne $taskExpected.Count) { throw 'MSI file table differs from generated source.' }
$taskActual = @(Get-ChildItem "$ExtractPath\payload" -Recurse -File)
if ($taskActual.Count -ne $taskExpected.Count) { throw 'MSI payload file count mismatch.' }
foreach ($taskFile in $taskExpected) {
    $taskMatches = @($taskActual | Where-Object { $_.Name -eq $taskFile.Id -or $_.Name -eq $taskFile.Name })
    if ($taskMatches.Count -ne 1) { throw "Missing/ambiguous extracted payload: $($taskFile.Id)" }
    if ((Get-FileHash -LiteralPath $taskMatches[0].FullName).Hash -ne (Get-FileHash -LiteralPath $taskFile.Source).Hash) { throw "MSI payload hash mismatch: $($taskFile.Name)" }
}
Write-Output "MSI readonly metadata/isolation and $($taskExpected.Count) extracted payload hashes PASS. No installation performed."
