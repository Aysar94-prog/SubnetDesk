#Requires -RunAsAdministrator
param([Parameter(Mandatory=$true)][string]$ServerName,[Parameter(Mandatory=$true)][string]$LanAddress)
$ErrorActionPreference = 'Stop'
if ($ServerName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.\-]{0,252}$') { throw 'Enter the DNS name or IPv4 address of this Deploy computer.' }
$interface = Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $LanAddress | Select-Object -First 1
if (-not $interface) { throw 'Select an IPv4 address assigned to the LAN interface on this computer.' }
function Set-ManagementTransport($certificate) {
    foreach ($binding in @('0.0.0.0:443','[::]:443')) {
        $current = & netsh.exe http show sslcert "ipport=$binding" 2>&1
        if ($LASTEXITCODE -eq 0) {
            if (($current -join ' ') -notmatch [regex]::Escape($certificate.Thumbprint)) { throw "Port $binding has a different certificate. It was not replaced." }
        } else {
            & netsh.exe http add sslcert "ipport=$binding" "certhash=$($certificate.Thumbprint)" 'appid={c91aa6dd-0fc5-44ab-80a8-333a9ae10908}' certstorename=MY
            if ($LASTEXITCODE -ne 0) { throw "HTTPS binding failed: $binding" }
        }
    }
    # The administrator explicitly selects the LAN interface. Cover public
    # profiles too, while keeping the source restricted to local subnets.
    $rule = 'SubnetDesk-Management-HTTPS'
    if (Get-NetFirewallRule -Name $rule -ErrorAction SilentlyContinue) {
        Set-NetFirewallRule -Name $rule -Enabled True -Profile Any -InterfaceAlias $interface.InterfaceAlias -RemoteAddress LocalSubnet -Action Allow
    } else {
        New-NetFirewallRule -Name $rule -DisplayName 'SubnetDesk Management HTTPS (selected LAN)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443 -Profile Any -InterfaceAlias $interface.InterfaceAlias -RemoteAddress LocalSubnet | Out-Null
    }
}
$root = Join-Path $env:ProgramData 'SubnetDesk Deployment'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetAccessRuleProtection($true,$false)
foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $root -AclObject $acl
$folder = Join-Path $root 'Management'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$path = Join-Path $folder 'config.json'
if (Test-Path -LiteralPath $path) {
    $existing = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($existing.server -ne "https://$ServerName/subnetdesk/") { throw 'A management server is already configured. Preserve its certificate and device registrations; migrate it explicitly.' }
    $certificate = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
        $digest = [Security.Cryptography.SHA256]::Create()
        try { [BitConverter]::ToString($digest.ComputeHash($_.RawData)).Replace('-','') -eq $existing.certificateSha256 } finally { $digest.Dispose() }
    } | Select-Object -First 1
    if (-not $certificate) { throw 'Existing management certificate not found. Restore it before provisioning.' }
    Set-ManagementTransport $certificate
    Start-Service SubnetDeskManagement
    Write-Output 'Management service already configured.'
    exit 0
}
# Never replace an unrelated application binding on 443.
& netsh.exe http show sslcert ipport=0.0.0.0:443 *> $null
if ($LASTEXITCODE -eq 0) { throw 'Port 443 already has an HTTPS certificate binding. Configure a dedicated IP/server before provisioning.' }
$parameters = @{ CertStoreLocation='Cert:\LocalMachine\My'; Type='SSLServerAuthentication'; KeyAlgorithm='RSA'; KeyLength=3072; HashAlgorithm='SHA256'; NotAfter=(Get-Date).AddYears(2); FriendlyName='SubnetDesk Management HTTPS' }
$ip = $null
if ([Net.IPAddress]::TryParse($ServerName,[ref]$ip)) {
    if (-not (Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $ServerName)) { throw 'This address is not assigned to the Deploy computer.' }
    $parameters.Subject = "CN=$ServerName"
    $parameters.TextExtension = @("2.5.29.17={text}IPAddress=$ServerName")
} else {
    $parameters.DnsName = @($ServerName)
}
$certificate = New-SelfSignedCertificate @parameters
$appid = '{c91aa6dd-0fc5-44ab-80a8-333a9ae10908}'
& netsh.exe http add sslcert ipport=0.0.0.0:443 certhash=$($certificate.Thumbprint) appid=$appid certstorename=MY
if ($LASTEXITCODE -ne 0) { throw 'HTTPS certificate binding failed.' }
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$sha = [Security.Cryptography.SHA256]::Create()
try { $pin = [BitConverter]::ToString($sha.ComputeHash($certificate.RawData)).Replace('-','') } finally { $sha.Dispose() }
$config = @{ server="https://$ServerName/subnetdesk/"; certificateSha256=$pin; adminToken=[Convert]::ToBase64String($bytes) }
$config | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
Set-ManagementTransport $certificate
Restart-Service SubnetDeskManagement
Write-Output 'Management ready. Agent connections use outbound HTTPS 443. Keep this server name/address stable.'
