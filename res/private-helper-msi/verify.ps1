param(
    [Parameter(Mandatory=$true)][string]$MsiPath,
    [Parameter(Mandatory=$true)][string]$PayloadXml,
    [Parameter(Mandatory=$true)][string]$ExtractPath,
    [string]$SevenZip = '7z.exe',
    [string]$ReleaseVersion = '1.3.7', [int]$ReleaseBuild = 85
)
$ErrorActionPreference = 'Stop'
$taskMachine = $ReleaseBuild -ge 87
if (Test-Path -LiteralPath $ExtractPath) { throw 'Preserve existing extraction directory.' }
$taskInstaller = New-Object -ComObject WindowsInstaller.Installer
$taskDatabase = $taskInstaller.OpenDatabase((Resolve-Path -LiteralPath $MsiPath).Path, 0)
$taskSummary = $taskDatabase.SummaryInformation(0)
if ($taskSummary.Property(7) -ne 'x64;1033' -or ((([int]$taskSummary.Property(15) -band 8) -eq 0) -ne $taskMachine)) { throw 'Expected x64 English MSI with correct Administrator requirement.' }
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
if ($taskMachine) {
    if ($taskProps['UpgradeCode'] -ne '{0351F62F-54C5-42BE-B162-C4F2088E7C39}' -or $taskProps['ALLUSERS'] -ne '1') { throw 'MSI private/machine identity mismatch.' }
    $taskLocators = @(Query 'SELECT `Root`, `Key`, `Name` FROM `RegLocator`' 3)
    if ($taskLocators.Count -ne 1 -or ($taskLocators[0] -join '|') -ne '1|Software\SubnetDeskPrivate\HelperInstaller|Shortcut') { throw 'Missing previous per-user installation detection.' }
    $taskConditions = @(Query 'SELECT `Condition` FROM `LaunchCondition`' 1 | ForEach-Object { $_[0] })
    if ($taskConditions -notcontains 'Installed OR NOT OLD_USER_HELPER') { throw 'Missing cross-context migration safety gate.' }
} elseif ($taskProps['UpgradeCode'] -ne '{76B63726-899A-49A7-95DF-52EF79D7C8C2}' -or $taskProps.ContainsKey('ALLUSERS')) { throw 'MSI private/per-user identity mismatch.' }
if ($ReleaseBuild -ge 86) {
    $taskSameVersionRows = @(Query 'SELECT `VersionMax`, `Attributes`, `ActionProperty` FROM `Upgrade`' 3 | Where-Object {
        $_[0] -eq $ReleaseVersion -and $_[2] -eq 'WIX_UPGRADE_DETECTED' -and ([int]$_[1] -band 512) -ne 0
    })
    $taskExpectedSameVersion = if ($ReleaseVersion -eq '1.3.7' -and $ReleaseBuild -eq 86) { 1 } else { 0 }
    if ($taskSameVersionRows.Count -ne $taskExpectedSameVersion) { throw 'Unexpected same-public-version private upgrade detection.' }
}
$taskDirectories = @{}
foreach ($taskRow in @(Query 'SELECT `Directory`, `Directory_Parent`, `DefaultDir` FROM `Directory`' 3)) { $taskDirectories[$taskRow[0]] = @($taskRow[1], ($taskRow[2] -split '\|')[-1]) }
if ($taskMachine) {
    if ($taskDirectories['INSTALLFOLDER'][0] -ne 'ProgramFiles64Folder' -or $taskDirectories['INSTALLFOLDER'][1] -ne 'SubnetDeskHelper') { throw 'Expected Program Files installation.' }
} elseif ($taskDirectories['INSTALLFOLDER'][0] -ne 'HelperPrograms' -or $taskDirectories['INSTALLFOLDER'][1] -ne 'SubnetDeskHelper' -or $taskDirectories['HelperPrograms'][0] -ne 'LocalAppDataFolder') { throw 'Unexpected install directory.' }
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
    $taskExpectedRoot = if ($taskMachine) { '2' } else { '1' }
    $taskExpectedKey = if ($taskMachine) { 'Software\SubnetDeskPrivate\HelperMachineInstaller' } else { 'Software\SubnetDeskPrivate\HelperInstaller' }
    if ($taskRow[0] -ne $taskExpectedRoot -or ($taskRow[1] -ne $taskExpectedKey -and $taskRow[1] -ne "$taskExpectedKey\Files")) { throw 'Unexpected installer registry target.' }
}
foreach ($taskRow in @(Query 'SELECT `FileName`, `InstallMode` FROM `RemoveFile`' 2)) {
    if ($taskRow[0] -or $taskRow[1] -ne '2') { throw 'MSI must remove empty owned folders only.' }
}
$taskShortcuts = @(Query 'SELECT `Shortcut`, `Directory_`, `Name`, `Target`, `WkDir`, `Component_` FROM `Shortcut`' 6)
if ($taskShortcuts.Count -ne $(if ($taskMachine) { 2 } else { 1 })) { throw 'Unexpected shortcut count.' }
foreach ($taskRow in $taskShortcuts) {
    $taskExpectedTarget = if ($taskMachine) { 'Complete' } else { '[INSTALLFOLDER]SubnetDesk.exe' }
    if ($taskRow[2] -notmatch 'SubnetDesk Helper$' -or $taskRow[3] -ne $taskExpectedTarget -or $taskRow[4] -ne 'INSTALLFOLDER') { throw 'Unexpected shortcut.' }
    if ($taskMachine) {
        $taskShortcutComponent = $taskRow[5]
        $taskKeys = @(Query ("SELECT ``KeyPath`` FROM ``Component`` WHERE ``Component`` = '$taskShortcutComponent'") 1)
        $taskKey = $taskKeys[0][0]
        $taskKeyFiles = @(Query ("SELECT ``FileName`` FROM ``File`` WHERE ``File`` = '$taskKey'") 1)
        if ($taskKeyFiles.Count -ne 1 -or ($taskKeyFiles[0][0] -split '\|')[-1] -ne 'SubnetDesk.exe') { throw 'Advertised shortcut must point to actual installed EXE.' }
    }
    if (($taskRow[0] -eq 'HelperStart' -and $taskRow[1] -eq 'HelperMenu') -or ($taskMachine -and $taskRow[0] -eq 'HelperDesktop' -and $taskRow[1] -eq 'DesktopFolder')) { continue }
    throw 'Unexpected shortcut location.'
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
