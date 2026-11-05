param([Parameter(Mandatory=$true)][string]$Msi)
$ErrorActionPreference='Stop'
$i=New-Object -ComObject WindowsInstaller.Installer
$path=(Resolve-Path $Msi).Path
$db=$i.OpenDatabase($path,0)
function Rows([string]$table,[int]$columns){
 $v=$db.OpenView('SELECT * FROM `'+$table+'`');$v.Execute()
 while($r=$v.Fetch()){$o=@{};for($n=1;$n -le $columns;$n++){$o["C$n"]=$r.StringData($n)};[pscustomobject]$o};$v.Close()
}
function Assert([bool]$value,[string]$message){if(!$value){throw $message}}
$props=@(Rows 'Property' 2)
Assert (@($props|Where-Object C1 -eq 'SET_UNATTENDED_PASSWORD').Count -eq 0) 'Checkbox must start unset; string 0 is not an unchecked MSI property'
$secure=($props|Where-Object C1 -eq 'SecureCustomProperties').C2.Split(';')
$hidden=($props|Where-Object C1 -eq 'MsiHiddenProperties').C2.Split(';')
foreach($name in @('SET_UNATTENDED_PASSWORD','UNATTENDED_PASSWORD','UNATTENDED_PASSWORD_CONFIRM','UNATTENDED_PASSWORD_B64')){Assert ($name -in $secure) "Missing secure property $name"}
foreach($name in @('UNATTENDED_PASSWORD','UNATTENDED_PASSWORD_CONFIRM','UNATTENDED_PASSWORD_B64')){Assert ($name -in $hidden) "Missing hidden property $name"}
$controls=@(Rows 'Control' 12)
$conditions=@(Rows 'ControlCondition' 4)
foreach($name in @('PasswordEdit','ConfirmEdit')){
 $c=$controls|Where-Object {$_.C1 -eq 'UnattendedPasswordDlg' -and $_.C2 -eq $name}
 Assert (([int]$c.C8 -band 2) -eq 0) "$name must start disabled"
 Assert (@($conditions|Where-Object {$_.C1 -eq 'UnattendedPasswordDlg' -and $_.C2 -eq $name -and $_.C3 -eq 'Disable'}).Count -eq 1) "$name needs disable condition"
}
$events=@(Rows 'ControlEvent' 6)
$next=@($events|Where-Object {$_.C1 -eq 'UnattendedPasswordDlg' -and $_.C2 -eq 'Next'}|Sort-Object {[int]$_.C6})
Assert (@($next|Where-Object {$_.C3 -eq 'NewDialog'}).Count -eq 1) 'Duplicate Next navigation bypasses validation'
Assert (@($events|Where-Object {$_.C1 -eq 'MaintenanceTypeDlg' -and $_.C2 -eq 'RepairButton' -and $_.C3 -eq 'NewDialog' -and $_.C4 -eq 'UnattendedPasswordDlg'}).Count -eq 1) 'Repair must allow updating unattended access'
$repairRoutes=@($events|Where-Object {$_.C1 -eq 'MaintenanceTypeDlg' -and $_.C2 -eq 'RepairButton' -and $_.C3 -eq 'NewDialog'})
Assert ($repairRoutes.Count -eq 1) 'Repair has duplicate navigation'
$seq=@(Rows 'InstallExecuteSequence' 3)
$prepare=$seq|Where-Object C1 -eq 'PrepareUnattendedPassword'
$apply=$seq|Where-Object C1 -eq 'SetUnattendedPassword'
$start=$seq|Where-Object C1 -eq 'CreateStartService'
Assert ([int]$prepare.C3 -lt [int]$start.C3 -and [int]$start.C3 -lt [int]$apply.C3) 'Incorrect service/password sequence'
# Virtual installer session: only manipulate in-memory properties and evaluate
# conditions. Never run DoAction, UI, InstallExecute or install custom actions.
$session=$i.OpenPackage($path,1)
function Put([string]$key,[string]$value){$null=$session.GetType().InvokeMember('Property',[Reflection.BindingFlags]::SetProperty,$null,$session,@($key,$value))}
function TrueCondition([string]$condition){$session.EvaluateCondition($condition) -eq 1}
$scenarios=@(
 @{Name='optional-empty';Select='';Password='';Confirm='';Navigate=$true;Apply=$false},
 @{Name='selected-empty';Select='1';Password='';Confirm='';Navigate=$false;Apply=$false},
 @{Name='selected-mismatch';Select='1';Password='synthetic-A';Confirm='synthetic-B';Navigate=$false;Apply=$true},
 @{Name='selected-matching';Select='1';Password='00synthetic-A';Confirm='00synthetic-A';Navigate=$true;Apply=$true},
 @{Name='unchecked-after-entry';Select='';Password='synthetic-A';Confirm='synthetic-A';Navigate=$true;Apply=$false}
)
foreach($case in $scenarios){
 Put 'SET_UNATTENDED_PASSWORD' $case.Select;Put 'UNATTENDED_PASSWORD' $case.Password;Put 'UNATTENDED_PASSWORD_CONFIRM' $case.Confirm;Put 'UNATTENDED_PASSWORD_B64' '';Put 'REMOVE' ''
 $navigate=$false
 foreach($event in $next){if(TrueCondition $event.C5){if($event.C3 -eq '[UNATTENDED_PASSWORD]'){Put 'UNATTENDED_PASSWORD' ''};if($event.C3 -eq '[UNATTENDED_PASSWORD_CONFIRM]'){Put 'UNATTENDED_PASSWORD_CONFIRM' ''};if($event.C3 -eq 'NewDialog'){$navigate=$true}}}
 Assert ($navigate -eq $case.Navigate) "$($case.Name): unexpected Next result"
 Assert ((TrueCondition $apply.C2) -eq $case.Apply) "$($case.Name): unexpected apply condition"
 "PASS $($case.Name)"
}
"PASS compiled MSI checkbox, field states, validation navigation, secure/hidden properties, repair route and action sequence"

# Explicit command-line credentials must not be silently skipped by an old or
# absent checkbox property. Inspect the generated type-51 normalizer as well.
$ca=@(Rows 'CustomAction' 4)
$normalizer=$ca|Where-Object {$_.C3 -eq 'SET_UNATTENDED_PASSWORD' -and $_.C4 -eq '1'}
Assert (@($normalizer).Count -eq 1) 'Missing unattended option normalizer'
$normalizeSequence=$seq|Where-Object C1 -eq $normalizer.C1
Put 'SET_UNATTENDED_PASSWORD' '0';Put 'UNATTENDED_PASSWORD' 'synthetic-command-line';Put 'ENABLE_UNATTENDED' '';Put 'REMOVE' ''
Assert (TrueCondition $normalizeSequence.C2) 'Explicit password must select replacement'
Put 'SET_UNATTENDED_PASSWORD' $normalizer.C4
Assert (TrueCondition $apply.C2) 'Explicit password replacement would be skipped'
Put 'REMOVE' 'ALL'
Assert (!(TrueCondition $normalizeSequence.C2)) 'Uninstall must not normalize password settings'
'PASS explicit-credential normalization and uninstall exclusion'

