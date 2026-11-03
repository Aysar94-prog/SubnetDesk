#Requires -RunAsAdministrator
param([Parameter(Mandatory=$true)][string]$EnrollmentFile)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $EnrollmentFile -Raw | ConvertFrom-Json
$uri = [Uri]$config.server
if ($uri.Scheme -ne 'https' -or $uri.AbsolutePath -ne '/subnetdesk/' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $config.certificateSha256 -notmatch '^[A-Fa-f0-9]{64}$' -or [Convert]::FromBase64String($config.enrollmentToken).Length -ne 32) { throw 'Invalid enrollment file.' }
$root = Join-Path $env:ProgramData 'SubnetDesk Deployment'
$folder = Join-Path $root 'Agent'
if (Test-Path -LiteralPath (Join-Path $folder 'config.json')) { throw 'This Agent is already configured. Do not replace its device identity during repair/upgrade.' }
New-Item -ItemType Directory -Force -Path $root | Out-Null
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetAccessRuleProtection($true,$false)
foreach ($sid in @('S-1-5-18','S-1-5-32-544')) { $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow')) }
Set-Acl -LiteralPath $root -AclObject $acl
New-Item -ItemType Directory -Force -Path $folder | Out-Null
@{ server=[string]$config.server; certificateSha256=[string]$config.certificateSha256; enrollmentToken=[string]$config.enrollmentToken } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'config.json') -Encoding utf8
Restart-Service SubnetDeskAgent
Write-Output 'Agent configured. Registration and installation results appear in Deploy. Delete the enrollment file after registration.'
