import 'dart:convert';
import 'dart:io';
import 'remote_helper_deployment.dart';

class ManagedDevice {
  ManagedDevice(this.data);
  final Map<String, dynamic> data;
  String text(String key) => (data[key] ?? '').toString();
  String get id => text('id');
  String get name => text('name').isEmpty ? text('machine') : text('name');
  String get address =>
      text('address').isEmpty ? text('machine') : text('address');
  bool get isAgent => text('transport') != 'domain';
  bool get revoked => data['revoked'] == true;
  bool get online => data['online'] == true && !revoked;
  bool get hasJob => data['job'] is Map;
  String get version => text('helperVersion').isEmpty
      ? (text('helperService').toLowerCase() == 'not installed'
            ? 'Not installed'
            : 'Not reported')
      : text('helperVersion');
  String get connection => revoked
      ? 'Revoked'
      : online
      ? (isAgent ? 'Online' : 'Ready')
      : isAgent
      ? (text('lastSeenUtc').isEmpty ? 'Enrolling' : 'Offline')
      : text('connectionState') == 'failed'
      ? 'Check failed'
      : 'Not verified';
  String get group => text('group').isEmpty ? 'Ungrouped' : text('group');
  String get transport => isAgent ? 'Agent' : 'Domain / WinRM';
}

List<ManagedDevice> filterManagedDevices(
  List<ManagedDevice> devices, {
  String query = '',
  String transport = 'all',
  String status = 'all',
  String group = '',
}) =>
    devices.where((d) {
        final search =
            '${d.name} ${d.address} ${d.group} ${d.text('domain')} ${d.id} ${d.text('machine')} ${d.text('agentVersion')} ${d.text('helperVersion')} ${d.text('operatingSystem')} ${d.text('architecture')} ${d.text('status')}'
                .toLowerCase();
        return search.contains(query.toLowerCase().trim()) &&
            (transport == 'all' || (transport == 'agent') == d.isAgent) &&
            (status == 'all' ||
                status == 'online' && d.online ||
                status == 'offline' && !d.online ||
                status == 'attention' &&
                    (d.revoked || d.text('status') == 'Failed')) &&
            (group.isEmpty || d.group == group);
      }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

class DomainDiscovery {
  static const script = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$searcher = [adsisearcher]'(&(objectCategory=computer)(operatingSystem=*Windows*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
$searcher.PageSize = 500
$searcher.ServerTimeLimit = [TimeSpan]::FromSeconds(25)
$searcher.PropertiesToLoad.Add('dnshostname') | Out-Null
$results = $null
try {
  $results = $searcher.FindAll()
  $hosts = @($results | ForEach-Object { if ($_.Properties['dnshostname'].Count) { [string]$_.Properties['dnshostname'][0] } })
  ConvertTo-Json -InputObject $hosts -Compress
} finally { if ($results) { $results.Dispose() }; $searcher.Dispose() }
''';
  static Future<List<String>> discover() async {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes.addAll([unit & 255, unit >> 8]);
    }
    final result = await Process.run(
      '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        base64.encode(bytes),
      ],
    ).timeout(const Duration(seconds: 40));
    if (result.exitCode != 0)
      throw const FormatException(
        'Active Directory discovery requires domain connectivity and directory read permission. You can import device names instead.',
      );
    final data = jsonDecode(
      (result.stdout as String).replaceFirst('\uFEFF', ''),
    );
    return parseDeploymentTargets((data is List ? data : [data]).join('\n'));
  }
}
