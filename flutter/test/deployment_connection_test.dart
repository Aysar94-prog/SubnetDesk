import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/remote_helper_deployment.dart';

void main() {
  test('CIDR and IP ranges expand with host boundaries and deduplication', () {
    final subnet = expandDeploymentRange('192.168.50.0/24');
    expect(subnet.length, 254);
    expect(subnet.first, '192.168.50.1');
    expect(subnet.last, '192.168.50.254');
    expect(expandDeploymentRange('192.168.50.8/31'), ['192.168.50.8','192.168.50.9']);
    expect(expandDeploymentRange('192.168.50.8/32'), ['192.168.50.8']);
    expect(expandDeploymentRange('192.168.48.0/22').length, 1022);
    expect(parseDeploymentTargets('192.168.50.1-192.168.50.3,192.168.50.2'),
      ['192.168.50.1','192.168.50.2','192.168.50.3']);
    for (final value in ['999.1.1.1/24','192.168.1.1/33','192.168.1.9-192.168.1.2','0.0.0.0/0']) {
      expect(() => expandDeploymentRange(value), throwsFormatException);
    }
  });
  test('local accounts use each target and preserve explicitly qualified accounts', () {
    expect(deploymentUsername('PC-A', r'.\user', DeploymentAccountType.local), r'PC-A\user');
    expect(deploymentUsername('PC-B', 'user', DeploymentAccountType.local), r'PC-B\user');
    expect(deploymentUsername('192.168.50.103', r'TARGET-PC\user', DeploymentAccountType.local), r'TARGET-PC\user');
    expect(deploymentUsername('PC', r'DOMAIN\user', DeploymentAccountType.qualified), r'DOMAIN\user');
  });
  test('WinRM classifier separates rejected credentials from permission and trust failures', () async {
    if (!Platform.isWindows) return;
    final script = '${PowerShellRemotingHelperDeployer.connectionErrorScript}\n'
      '[Console]::OutputEncoding = [Text.UTF8Encoding]::new(\$false)\n'
      '@("Logon failure 0x8007052e", "Access is denied 0x80070005", "TrustedHosts credentials required", "SSL certificate invalid") | '
      'ForEach-Object { (Get-ConnectionFailure \$_).code } | ConvertTo-Json -Compress';
    final bytes = <int>[];
    for (final unit in script.codeUnits) { bytes.addAll([unit & 255, unit >> 8]); }
    final result = await Process.run('${Platform.environment['SystemRoot']}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      ['-NoProfile','-NonInteractive','-EncodedCommand',base64.encode(bytes)]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(jsonDecode(result.stdout as String), ['bad_credentials','permissions','trust','certificate']);
  });
  test('connection test needs no MSI and reports an unreachable host before authentication', () async {
    if (!Platform.isWindows) return;
    final result = await PowerShellRemotingHelperDeployer().deploy(
      const RemoteHelperDeploymentRequest(target:'subnetdesk-test.invalid', username:'not-used',
        administratorPassword:'not-sent',msiPath:'',testOnly:true));
    expect(result.succeeded, false);
    expect(result.message.toLowerCase(), contains('offline or unreachable'));
    expect(result.message, contains('Password has not been tested'));
  });
}
