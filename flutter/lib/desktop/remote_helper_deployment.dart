import 'dart:convert';
import 'dart:io';

class HelperMsiPackage {
  const HelperMsiPackage(
    this.path,
    this.version,
    this.productCode,
    this.sha256,
  );
  final String path;
  final String version;
  final String productCode;
  final String sha256;
  static const inspectionScript = r'''
$ErrorActionPreference = 'Stop'
$path = [IO.Path]::GetFullPath([Console]::In.ReadLine())
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.OpenDatabase($path, 0)
function Read-Property($name) {
  $view = $db.OpenView("SELECT ``Value`` FROM ``Property`` WHERE ``Property``='$name'")
  $view.Execute() | Out-Null
  $record = $view.Fetch()
  if (-not $record) { throw 'Missing MSI property' }
  return $record.StringData(1)
}
$name = Read-Property 'ProductName'
if ($name -notmatch '(?i)SubnetDesk' -or $name -match '(?i)Deploy|Agent') { throw 'Select a SubnetDesk Helper MSI' }
if ((Read-Property 'UpgradeCode') -ne '{DC0E791C-3B4D-5A51-9AA8-629D81975868}') { throw 'Select a package from the SubnetDesk Helper product family' }
$stream = [IO.File]::OpenRead($path)
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
finally { $stream.Dispose(); $sha.Dispose() }
@{ version = (Read-Property 'ProductVersion'); productCode = (Read-Property 'ProductCode'); sha256 = $hash } | ConvertTo-Json -Compress
''';
  static Future<HelperMsiPackage> inspect(String path) async {
    if (!Platform.isWindows || !await File(path).exists()) {
      throw const FormatException('Select an existing Windows Helper MSI.');
    }
    final bytes = <int>[];
    for (final unit in inspectionScript.codeUnits) {
      bytes.addAll([unit & 255, unit >> 8]);
    }
    final process = await Process.start(
      '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        base64.encode(bytes),
      ],
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.writeln(path);
    await process.stdin.close();
    final code = await process.exitCode;
    final text = await output;
    final diagnostic = await errors;
    if (code != 0) {
      throw FormatException(
        'Could not read a valid SubnetDesk Helper MSI. $diagnostic',
      );
    }
    final data = jsonDecode(text) as Map<String, dynamic>;
    return HelperMsiPackage(
      path,
      data['version'] as String,
      data['productCode'] as String,
      data['sha256'] as String,
    );
  }
}

List<String> expandDeploymentRange(String input) {
  int ip(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4)
      throw const FormatException('Enter an IPv4 subnet or full IP range.');
    var result = 0;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255)
        throw const FormatException('Invalid IPv4 address.');
      result = (result << 8) | n;
    }
    return result;
  }

  String address(int n) =>
      [24, 16, 8, 0].map((shift) => (n >> shift) & 255).join('.');
  int first, last;
  if (input.contains('/')) {
    final parts = input.trim().split('/');
    if (parts.length != 2) throw const FormatException('Invalid CIDR subnet.');
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32)
      throw const FormatException('CIDR prefix must be 0–32.');
    final size = 1 << (32 - prefix);
    if (size > 65536)
      throw const FormatException(
        'Use a smaller subnet (at most /16 per expansion).',
      );
    final network = ip(parts[0]) & (0xffffffff ^ (size - 1));
    first = network + (prefix < 31 ? 1 : 0);
    last = network + size - 1 - (prefix < 31 ? 1 : 0);
  } else {
    final parts = input.trim().split('-');
    if (parts.length != 2)
      throw const FormatException(
        'Use 192.168.50.0/24 or 192.168.50.10-192.168.50.200.',
      );
    first = ip(parts[0]);
    last = ip(parts[1]);
    if (last < first)
      throw const FormatException('The range end must follow its start.');
    if (last - first + 1 > 65536)
      throw const FormatException('Use a smaller IP range.');
  }
  return List.generate(last - first + 1, (i) => address(first + i));
}

List<String> parseDeploymentTargets(String text) {
  final seen = <String>{};
  final result = <String>[];
  for (final token
      in text.split(RegExp(r'[\s,;]+')).where((s) => s.isNotEmpty)) {
    final values =
        token.contains('/') || RegExp(r'^\d+\.\d+\.\d+\.\d+-').hasMatch(token)
        ? expandDeploymentRange(token)
        : [token];
    for (final target in values) {
      if (seen.add(target.toLowerCase())) result.add(target);
    }
  }
  return result;
}

enum DeploymentAccountType { qualified, local }

String deploymentUsername(
  String target,
  String username,
  DeploymentAccountType type,
) {
  var user = username.trim();
  if (user.startsWith(r'.\')) user = user.substring(2);
  if (user.isEmpty)
    throw const FormatException('Enter an administrator username.');
  if (type == DeploymentAccountType.local &&
      !user.contains(r'\') &&
      !user.contains('@')) {
    return '$target\\$user';
  }
  return user;
}

class BulkHelperDeployment {
  Future<void> run(
    List<RemoteHelperDeploymentRequest> requests,
    RemoteHelperDeployer deployer, {
    int concurrency = 20,
    required void Function(String, RemoteHelperDeploymentResult) onResult,
    bool Function()? cancelled,
  }) async {
    if (concurrency < 1) throw ArgumentError.value(concurrency);
    var next = 0;
    Future<void> worker() async {
      while (next < requests.length && !(cancelled?.call() ?? false)) {
        final request = requests[next++];
        RemoteHelperDeploymentResult result;
        try {
          result = await deployer.deploy(request);
        } catch (_) {
          result = const RemoteHelperDeploymentResult(
            succeeded: false,
            message: 'Deployment failed.',
          );
        }
        onResult(request.target, result);
      }
    }

    await Future.wait(
      List.generate(
        concurrency < requests.length ? concurrency : requests.length,
        (_) => worker(),
      ),
    );
  }
}

/// Inputs for a remote Helper install. Secrets stay in the process stdin pipe;
/// they are never added to PowerShell's command line or written to a temp file.
class RemoteHelperDeploymentRequest {
  const RemoteHelperDeploymentRequest({
    required this.target,
    required this.username,
    required this.administratorPassword,
    required this.msiPath,
    this.configureUnattended = false,
    this.unattendedPassword = '',
    this.package,
    this.accountType = DeploymentAccountType.qualified,
    this.useSsl = true,
    this.prepareHttps = false,
    this.testOnly = false,
    this.action = 'install',
  });
  final String target;
  final String username;
  final String administratorPassword;
  final String msiPath;
  final bool configureUnattended;
  final String unattendedPassword;
  final HelperMsiPackage? package;
  final DeploymentAccountType accountType;
  final bool useSsl;
  final bool prepareHttps;
  final bool testOnly;
  final String action;
}

class RemoteHelperDeploymentResult {
  const RemoteHelperDeploymentResult({
    required this.succeeded,
    required this.message,
    this.inventory,
  });
  final bool succeeded;
  final String message;
  final Map<String, dynamic>? inventory;
}

/// Deployment-method boundary for future trusted-device and enterprise
/// transports. The initial implementation requires authenticated WinRM.
abstract interface class RemoteHelperDeployer {
  Future<RemoteHelperDeploymentResult> deploy(
    RemoteHelperDeploymentRequest request,
  );
}

class PowerShellRemotingHelperDeployer implements RemoteHelperDeployer {
  // Bootstrap is restricted to Kerberos: never learn certificate trust from an
  // unauthenticated TLS connection or silently change TrustedHosts.
  static const httpsSetupScript = r'''
function Initialize-TargetHttps($request, $credential) {
  $bootstrap = $null
  try {
    $bootstrap = New-PSSession -ComputerName ([string]$request.target) -Authentication Kerberos -Credential $credential -SessionOption (New-PSSessionOption -OpenTimeout 15000) -ErrorAction Stop
    $certificate = Invoke-Command -Session $bootstrap -ArgumentList ([string]$request.target) -ScriptBlock {
      param($targetName)
      $ErrorActionPreference = 'Stop'
      $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
      if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'HTTPS setup requires target administrator rights.' }
      if (Get-ChildItem WSMan:\localhost\Listener | Where-Object { $_.Keys -contains 'Transport=HTTPS' }) {
        throw 'An HTTPS listener already exists. Check its port, firewall and certificate; it was not replaced.'
      }
      $cert = New-SelfSignedCertificate -DnsName @($targetName, $env:COMPUTERNAME) -CertStoreLocation Cert:\LocalMachine\My -Type SSLServerAuthentication -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(1) -FriendlyName 'SubnetDesk Deploy WinRM HTTPS'
      New-Item WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force | Out-Null
      $ruleName = 'SubnetDesk-Deploy-WinRM-HTTPS'
      if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name $ruleName -DisplayName 'SubnetDesk Deploy WinRM HTTPS' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986 -Profile Domain,Private -RemoteAddress LocalSubnet | Out-Null
      }
      [Convert]::ToBase64String($cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    }
    $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String([string]$certificate))
    $store = [Security.Cryptography.X509Certificates.X509Store]::new('Root', 'CurrentUser')
    try { $store.Open('ReadWrite'); $store.Add($cert) } finally { $store.Close(); $cert.Dispose() }
  } finally { if ($bootstrap) { Remove-PSSession $bootstrap -ErrorAction SilentlyContinue } }
}
''';
  static const connectionErrorScript = r'''
function Get-ConnectionFailure([string]$errorText) {
    if ($errorText -match '(?i)TrustedHosts|Kerberos|workgroup') {
      return @{ code = 'trust'; message = 'Online — WinRM authentication policy blocks this connection. Verify the HTTPS certificate, target DNS name and account configuration.' }
    } elseif ($errorText -match '(?i)1326|8007052e|logon failure|user name or password is incorrect|unknown user name or bad password') {
      return @{ code = 'bad_credentials'; message = 'Online — wrong username or password. Use the target computer local account (TARGET-PC\user), and its Windows password, not a PIN.' }
    } elseif ($errorText -match '(?i)certificate|SSL|TLS') {
      return @{ code = 'certificate'; message = 'Online — WinRM HTTPS certificate could not be validated. Check the target name and certificate trust.' }
    } elseif ($errorText -match '(?i)access is denied|accessdenied|unauthorized|80070005') {
      return @{ code = 'permissions'; message = 'Online — access denied. Check the target local username, administrator membership and WinRM endpoint permissions; local-account UAC filtering may also restrict access. Windows did not confirm a wrong password.' }
    } else { return @{ code = 'connection'; message = 'Online — WinRM HTTPS session failed. Check the listener on 5986, certificate trust and authentication policy.' } }
}
''';
  static const _script =
      connectionErrorScript +
      httpsSetupScript +
      r'''
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
function Send-Result([string]$code, [string]$message, [bool]$ok = $false) {
  [Console]::Out.WriteLine((ConvertTo-Json -Depth 5 -Compress @{ ok = $ok; code = $code; message = $message; inventory = $inventory }))
}
$request = $null
$session = $null
$remoteMsi = $null
$securePassword = $null
$credential = $null
$inventory = $null
$stage = 'input'
try {
  $line = [Console]::In.ReadLine()
  if ([string]::IsNullOrWhiteSpace($line)) { Send-Result 'input' 'Deployment request was empty.'; return }
  $request = $line | ConvertFrom-Json
  $stage = 'reachability'
  $port = 5986
  $tcp = [Net.Sockets.TcpClient]::new()
  $open = $false
  try { $connect = $tcp.ConnectAsync([string]$request.target, $port); $open = $connect.Wait(3000) -and $tcp.Connected } catch {} finally { $tcp.Dispose() }
  if (-not $open -and [bool]$request.prepareHttps) {
    $securePassword = [Security.SecureString]::new()
    foreach ($character in ([string]$request.administratorPassword).ToCharArray()) { $securePassword.AppendChar($character) }
    $credential = [System.Management.Automation.PSCredential]::new([string]$request.username, $securePassword)
    $request.administratorPassword = $null
    try { Initialize-TargetHttps $request $credential; $open = $true }
    catch { Send-Result 'https_setup' ('HTTPS setup failed. Requires an existing Kerberos-authenticated WinRM channel using the target DNS name, or local/GPO provisioning. ' + $_.Exception.Message); return }
  }
  if (-not $open) {
    $online = $false
    $ping = [Net.NetworkInformation.Ping]::new()
    try { $online = $ping.Send([string]$request.target, 1500).Status -eq 'Success' } catch {} finally { $ping.Dispose() }
    if ($online) { Send-Result 'winrm_unavailable' ('Online — WinRM port ' + $port + ' is blocked or not listening. Enable WinRM and its firewall rule on the target. Password has not been tested.') }
    else { Send-Result 'offline' ('Offline or unreachable — no ICMP reply or WinRM response on port ' + $port + '. Password has not been tested.') }
    return
  }
  $stage = 'credentials'
  if (-not $credential) {
    $securePassword = [Security.SecureString]::new()
    foreach ($character in ([string]$request.administratorPassword).ToCharArray()) { $securePassword.AppendChar($character) }
    $credential = [System.Management.Automation.PSCredential]::new([string]$request.username, $securePassword)
    $request.administratorPassword = $null
  }
  try {
    $options = New-PSSessionOption -OpenTimeout 15000
    $uri = [UriBuilder]::new('https', [string]$request.target, 5986, '/wsman').Uri
    $session = New-PSSession -ConnectionUri $uri -Credential $credential -Authentication Negotiate -SessionOption $options -ErrorAction Stop
  } catch {
    $errorText = [string]$_.Exception.Message + ' ' + [string]$_.FullyQualifiedErrorId
    $failure = Get-ConnectionFailure $errorText
    Send-Result $failure.code $failure.message
    return
  }
  $admin = Invoke-Command -Session $session -ScriptBlock {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }
  if (-not $admin) { Send-Result 'permissions' 'Online — password accepted, but the remote session does not have administrator rights.'; return }
  if ([bool]$request.testOnly) {
    $inventory = Invoke-Command -Session $session -ScriptBlock {
      $facts = @{ helperVersion = ''; helperService = 'Not installed'; machine = $env:COMPUTERNAME }
      try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        foreach ($product in @($installer.RelatedProducts('{DC0E791C-3B4D-5A51-9AA8-629D81975868}'))) { $name = [string]$installer.ProductInfo($product, 'ProductName'); if ($name -notmatch '(?i)SubnetDesk' -or $name -match '(?i)Deploy|Agent') { continue }; $facts.helperVersion = [string]$installer.ProductInfo($product, 'VersionString'); break }
      } catch { $facts.inventoryWarning = 'MSI inventory unavailable.' }
      $service = Get-Service SubnetDesk -ErrorAction SilentlyContinue
      if ($service) { $facts.helperService = [string]$service.Status }
      try {
        $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $facts.domain = [string]$computer.Domain; $facts.domainJoined = [bool]$computer.PartOfDomain
        $facts.operatingSystem = [string]$os.Caption; $facts.architecture = [string]$os.OSArchitecture
      } catch { $facts.inventoryWarning = 'System inventory unavailable.' }
      return $facts
    }
    Send-Result 'ready' 'Online — credentials accepted, administrator access verified and available inventory refreshed.' $true; return
  }
  if ([string]$request.action -ne 'install') {
    $outcome = Invoke-Command -Session $session -ArgumentList ([string]$request.action) -ScriptBlock {
      param($action)
      if ($action -notin @('repair','uninstall','start','stop','restart')) { throw 'Unsupported Helper action.' }
      if ($action -in @('repair','uninstall')) {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $installer.UILevel = 2
        $products = @($installer.RelatedProducts('{DC0E791C-3B4D-5A51-9AA8-629D81975868}') | Where-Object { $name = [string]$installer.ProductInfo([string]$_, 'ProductName'); $name -match '(?i)SubnetDesk' -and $name -notmatch '(?i)Deploy|Agent' })
        if ($products.Count -eq 0) { if ($action -eq 'uninstall') { return 'Helper is already uninstalled.' }; throw 'Helper is not installed.' }
        foreach ($product in $products) {
          if ($action -eq 'uninstall') { $installer.ConfigureProductEx($product, 0, 2, 'REBOOT=ReallySuppress') }
          else { $installer.ConfigureProductEx($product, 0, 5, 'REINSTALL=ALL REINSTALLMODE=omus REBOOT=ReallySuppress LAUNCH_TRAY_APP=N') }
        }
        if ($action -eq 'uninstall') {
          if (@($installer.RelatedProducts('{DC0E791C-3B4D-5A51-9AA8-629D81975868}') | Where-Object { $name = [string]$installer.ProductInfo([string]$_, 'ProductName'); $name -match '(?i)SubnetDesk' -and $name -notmatch '(?i)Deploy|Agent' }).Count -gt 0) { throw 'Removal verification failed.' }
          return 'Helper uninstalled.'
        }
      }
      $service = Get-Service SubnetDesk -ErrorAction Stop
      if ($action -in @('stop','restart') -and $service.Status -ne 'Stopped') { Stop-Service SubnetDesk -ErrorAction Stop; $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30)) }
      if ($action -ne 'stop') { $service.Refresh(); if ($service.Status -eq 'Stopped') { Start-Service SubnetDesk -ErrorAction Stop }; $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30)) }
      return ('Helper ' + $action + ' completed; service verified.')
    }
    Send-Result 'success' ([string]$outcome) $true; return
  }
  $securePassword.Dispose()
  $credential = $null

  $stage = 'copy'
  $remoteMsi = Invoke-Command -Session $session -ScriptBlock { Join-Path $env:TEMP ('SubnetDesk-' + [guid]::NewGuid().ToString('N') + '.msi') }
  $copied = $false
  for ($attempt = 1; $attempt -le 3 -and -not $copied; $attempt++) {
    try {
      Copy-Item -LiteralPath ([string]$request.msiPath) -Destination $remoteMsi -ToSession $session -ErrorAction Stop
      $copied = $true
    } catch {
      if ($attempt -lt 3) { Start-Sleep -Seconds 1 }
    }
  }
  if (-not $copied) {
    Send-Result 'copy' 'Connected, but copying the MSI to the target failed.'
    return
  }

  $stage = 'install'
  $copiedHash = Invoke-Command -Session $session -ArgumentList $remoteMsi -ScriptBlock {
    param($path)
    $stream = [IO.File]::OpenRead($path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
  }
  if ($copiedHash -ne [string]$request.sha256) { Send-Result 'copy' 'The copied MSI differs from the selected package.'; return }
  $encodedPassword = ''
  if ([bool]$request.configureUnattended) {
    $encodedPassword = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$request.unattendedPassword))
    $request.unattendedPassword = $null
    if ($encodedPassword.Length -gt 240) {
      Send-Result 'unattended' 'The unattended access password is too long for secure MSI property transfer.'
      return
    }
  }
  $install = Invoke-Command -Session $session -ArgumentList $remoteMsi, ([bool]$request.configureUnattended), $encodedPassword -ScriptBlock {
    param($packagePath, $configure, $passwordB64)
    try {
      $arguments = 'UILevel=2 REBOOT=ReallySuppress LAUNCH_TRAY_APP=N'
      if ($configure) { $arguments += ' SET_UNATTENDED_PASSWORD=1 UNATTENDED_PASSWORD_B64=' + $passwordB64 }
      $installer = New-Object -ComObject WindowsInstaller.Installer
      $installer.UILevel = 2
      if ($configure) {
        $database = $installer.OpenDatabase($packagePath, 0)
        foreach ($action in @('PrepareUnattendedPassword', 'SetUnattendedPassword')) {
          $view = $database.OpenView("SELECT ``Action`` FROM ``CustomAction`` WHERE ``Action``='$action'")
          $view.Execute(); $record = $view.Fetch(); $view.Close()
          if (-not $record) { return @{ ok = $false; code = 87; unsupportedUnattended = $true } }
        }
      }
      $installer.InstallProduct($packagePath, $arguments)
      return @{ ok = $true; code = 0 }
    } catch {
      $nativeCode = [int]([uint32]$_.Exception.HResult -band 0xffff)
      return @{ ok = $false; code = $nativeCode }
    }
  }
  if (-not $install -or -not $install.ok) {
    if ($install.unsupportedUnattended) {
      Send-Result 'unattended' 'Selected Helper MSI does not support unattended password configuration.'
      return
    }
    if ([bool]$request.configureUnattended) {
      Send-Result 'unattended' ('MSI installation or unattended access configuration failed (Windows Installer code ' + [string]$install.code + ').')
    } else {
      Send-Result 'install' ('The MSI installation failed (Windows Installer code ' + [string]$install.code + ').')
    }
    return
  }

  $stage = 'verify'
  $verified = Invoke-Command -Session $session -ArgumentList ([bool]$request.configureUnattended), ([string]$request.productCode), ([string]$request.version) -ScriptBlock {
    param($configure, $productCode, $version)
    try {
      $installer = New-Object -ComObject WindowsInstaller.Installer
      if ($installer.ProductInfo($productCode, 'VersionString') -ne $version) { return @{ ok = $false; code = 'version' } }
    } catch { return @{ ok = $false; code = 'version' } }
    $exe = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'SubnetDesk\SubnetDesk.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { return @{ ok = $false; code = 'executable' } }
    try { $service = Get-Service -Name 'SubnetDesk' -ErrorAction Stop }
    catch { return @{ ok = $false; code = 'service_missing' } }
    if ($service.Status -eq 'Stopped') {
      try { Start-Service -Name 'SubnetDesk' -ErrorAction Stop }
      catch { return @{ ok = $false; code = 'service_start' } }
    }
    try { (Get-Service -Name 'SubnetDesk').WaitForStatus('Running', [TimeSpan]::FromSeconds(30)) }
    catch { return @{ ok = $false; code = 'service_stopped' } }
    # A requested password is applied by the MSI's deferred, fail-on-error
    # custom action. Reaching this check means that action returned success.
    return @{ ok = $true; code = 'verified'; unattended = $configure }
  }
  if (-not $verified -or -not $verified.ok) {
    $message = switch ([string]$verified.code) {
      'version' { 'The selected Helper version could not be verified on the target.' }
      'executable' { 'Installation completed, but SubnetDesk.exe was not found in Program Files.' }
      'service_missing' { 'Installation completed, but the SubnetDesk service was not created.' }
      'service_start' { 'Installation completed, but the SubnetDesk service could not be started.' }
      default { 'Installation completed, but the SubnetDesk service is not running.' }
    }
    Send-Result 'verify' $message
    return
  }
  if ($verified.unattended) { Send-Result 'success' 'Helper installed, service running, and unattended access configured.' $true }
  else { Send-Result 'success' 'Helper installed and service running.' $true }
} catch {
  $message = switch ($stage) {
    'copy' { 'Copying the MSI to the target failed.' }
    'install' { 'MSI installation failed. Check administrator rights and Windows Installer status.' }
    'unattended' { 'Unattended access setup failed. Check the password and MSI configuration.' }
    default { 'Remote deployment failed. Check PowerShell Remoting and administrator access.' }
  }
  Send-Result $stage $message
} finally {
  if ($securePassword) { $securePassword.Dispose() }
  if ($session) {
    if ($remoteMsi) {
      try { Invoke-Command -Session $session -ArgumentList $remoteMsi -ScriptBlock { param($path) Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } | Out-Null } catch {}
    }
    Remove-PSSession -Session $session -ErrorAction SilentlyContinue
  }
  if ($request) {
    $request.administratorPassword = $null
    $request.unattendedPassword = $null
  }
}
''';
  @override
  Future<RemoteHelperDeploymentResult> deploy(
    RemoteHelperDeploymentRequest request,
  ) async {
    if (!Platform.isWindows) {
      return const RemoteHelperDeploymentResult(
        succeeded: false,
        message:
            'Remote Helper deployment is currently supported from Windows only.',
      );
    }
    HelperMsiPackage? package;
    String username;
    try {
      username = deploymentUsername(request.target, request.username, request.accountType);
      if (!['install','repair','uninstall','start','stop','restart'].contains(request.action)) throw const FormatException('Unsupported action.');
      if (!request.testOnly && request.action == 'install') {
        package =
            request.package ?? await HelperMsiPackage.inspect(request.msiPath);
        if (package.path != request.msiPath) throw const FormatException();
      }
    } catch (_) {
      return const RemoteHelperDeploymentResult(
        succeeded: false,
        message: 'Select a valid Helper MSI before deployment.',
      );
    }
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final powershell = joinPath(
      systemRoot,
      r'System32\WindowsPowerShell\v1.0\powershell.exe',
    );
    final scriptBytes = <int>[];
    for (final codeUnit in _script.codeUnits) {
      scriptBytes
        ..add(codeUnit & 0xff)
        ..add((codeUnit >> 8) & 0xff);
    }
    final encodedScript = base64.encode(scriptBytes);
    Process process;
    try {
      process = await Process.start(powershell, [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'& ([scriptblock]::Create([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([Console]::In.ReadLine())))); exit 0',
      ], runInShell: false);
    } catch (_) {
      return const RemoteHelperDeploymentResult(
        succeeded: false,
        message:
            'PowerShell could not be started. Check that Windows PowerShell is available.',
      );
    }
    final stdout = process.stdout.transform(utf8.decoder).join();
    // Consume stderr without returning it: PowerShell diagnostics can contain
    // sensitive request data and should never be displayed or logged.
    final stderr = process.stderr.drain<void>();
    final requestBytes = utf8.encode(
      jsonEncode({
        'target': request.target.trim(),
        'username': username,
        'useSsl': true,
        'prepareHttps': request.prepareHttps,
        'testOnly': request.testOnly,
        'action': request.action,
        'administratorPassword': request.administratorPassword,
        'msiPath': request.msiPath,
        'version': package?.version ?? '',
        'productCode': package?.productCode ?? '',
        'sha256': package?.sha256 ?? '',
        'configureUnattended': request.configureUnattended,
        'unattendedPassword': request.configureUnattended
            ? request.unattendedPassword
            : '',
      }),
    );
    // Clear the UI fields while deployment proceeds. The request itself stays
    // in memory only for the remoting call and is never logged or persisted.
    try {
      process.stdin.writeln(encodedScript);
      process.stdin.add(requestBytes);
      process.stdin.add(const [10]);
      await process.stdin.flush();
      requestBytes.fillRange(0, requestBytes.length, 0);
      await process.stdin.close();
      final output = await stdout.timeout(Duration(minutes: request.testOnly ? 1 : 30));
      await stderr;
      await process.exitCode;
      final resultLine = output
          .trim()
          .split('\n')
          .lastWhere((line) => line.trim().isNotEmpty, orElse: () => '');
      final result = jsonDecode(resultLine) as Map<String, dynamic>;
      return RemoteHelperDeploymentResult(
        succeeded: result['ok'] == true,
        message:
            (result['message'] as String?) ??
            'Remote deployment returned an invalid status.',
        inventory: result['inventory'] is Map ? Map<String, dynamic>.from(result['inventory'] as Map) : null,
      );
    } catch (_) {
      process.kill();
      return const RemoteHelperDeploymentResult(
        succeeded: false,
        message:
            'Remote deployment ended without a verifiable status. Check the target and try again.',
      );
    }
  }

  static String joinPath(String left, String right) =>
      '$left${left.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}$right';
}
