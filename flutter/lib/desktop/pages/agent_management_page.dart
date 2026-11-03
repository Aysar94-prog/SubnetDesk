import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent_management.dart';
import '../remote_helper_deployment.dart';

class AgentManagementPage extends StatefulWidget {
  const AgentManagementPage({super.key});
  @override
  State<AgentManagementPage> createState() => _AgentManagementPageState();
}

class _AgentManagementPageState extends State<AgentManagementPage> {
  final _host = TextEditingController(text: Platform.localHostname);
  final _lanAddress = TextEditingController();
  List<String> _addresses = [];
  final _label = TextEditingController(text: 'Device');
  final _count = TextEditingController(text: '1');
  final _selected = <String>{};
  List<Map<String, dynamic>> _devices = [];
  AgentManagementClient? _client;
  HelperMsiPackage? _package;
  Timer? _timer;
  bool _busy = false;
  String _status = 'Run Deploy as administrator. Initialize the management server once, then export enrollment files for Agent devices.';
  String _action = 'install';
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    NetworkInterface.list(type: InternetAddressType.IPv4).then((interfaces) {
      if (!mounted) return;
      setState(() => _addresses = interfaces.expand((i) => i.addresses).map((a) => a.address).toList());
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_busy && _client != null) _run(_refresh);
    });
  }
  @override
  void dispose() {
    _timer?.cancel(); _client?.close();
    _host.dispose(); _lanAddress.dispose(); _label.dispose(); _count.dispose();
    super.dispose();
  }
  Future<AgentManagementClient> _connection() async =>
      _client ??= await AgentManagementClient.local();

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); }
    on FileSystemException { if (mounted) setState(() => _status = 'Cannot read local management configuration. Run Deploy as administrator and initialize the server first.'); }
    catch (e) { if (mounted) setState(() => _status = e is HttpException ? e.message : 'Operation failed. Check the management service, certificate and protected configuration.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _refresh() async {
    final result = await (await _connection()).call('devices');
    if (!mounted) return;
    setState(() {
      _devices = (result['devices'] as List).cast<Map<String, dynamic>>();
      _selected.removeWhere((id) => !_devices.any((device) => device['id'] == id && device['revoked'] != true));
    });
  }
  Future<void> _initialize() async {
    final name = _host.text.trim();
    if (!_addresses.contains(_lanAddress.text)) { setState(() => _status = 'Select the LAN interface/address used by your target devices.'); return; }
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]{0,252}$').hasMatch(name)) {
      setState(() => _status = 'Enter the DNS name or IPv4 address of this Deploy computer.'); return;
    }
    final directory = File(Platform.resolvedExecutable).parent.path;
    final script = '$directory\\deployment\\Initialize-Management.ps1';
    final result = await Process.run(
      '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script, '-ServerName', name, '-LanAddress', _lanAddress.text],
    );
    if (result.exitCode != 0) {
      setState(() => _status = 'Setup failed. Run Deploy as administrator; verify port 443 is available and the management service is installed. Existing HTTPS bindings are never replaced.'); return;
    }
    _client?.close(); _client = null;
    for (var attempt = 0; ; attempt++) {
      try { await _refresh(); break; }
      catch (_) {
        if (attempt >= 14) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    if (mounted) setState(() => _status = 'Management HTTPS service ready at https://$name/subnetdesk/. Export enrollment files next.');
  }
  Future<void> _enrollment() async {
    final count = int.tryParse(_count.text);
    if (count == null || count < 1 || _label.text.trim().isEmpty) {
      setState(() => _status = 'Enter a device label and a positive enrollment count.'); return;
    }
    final folder = await FilePicker.getDirectoryPath(dialogTitle: 'Save private Agent enrollment files');
    if (folder == null) return;
    final installer = File('${File(Platform.resolvedExecutable).parent.path}\\deployment\\SubnetDeskAgent.exe');
    if (!await installer.exists()) {
      setState(() => _status = 'Agent installer is missing from this Deploy installation. Repair Deploy first.'); return;
    }
    final installerCopy = File('$folder\\SubnetDeskAgent.exe');
    if (!await installerCopy.exists()) await installer.copy(installerCopy.path);
    final client = await _connection();
    final batch = DateTime.now().microsecondsSinceEpoch;
    for (var i = 1; i <= count; i++) {
      final config = await client.call('enrollment', body: {'name': '${_label.text.trim()}-$i'});
      final file = File('$folder\\SubnetDesk-enrollment-$batch-$i.json');
      await file.writeAsString(jsonEncode(config), flush: true);
    }
    if (mounted) setState(() => _status = 'Agent EXE and $count enrollment files exported. Open SubnetDeskAgent.exe on each target, import its enrollment file in Settings, then Save & connect. No PowerShell is required.');
  }
  Future<void> _browse() async {
    final pick = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['msi']);
    final path = pick?.files.single.path;
    if (path == null) return;
    final metadata = await HelperMsiPackage.inspect(path);
    if (mounted) setState(() => _package = metadata);
  }
  Future<void> _deploy() async {
    final package = _package;
    if ((_action == 'install' && package == null) || _selected.isEmpty) return;
    if (_action == 'uninstall' || _action == 'stop') {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text(_action == 'uninstall' ? 'Uninstall Helper?' : 'Stop Helper service?'),
        content: Text('Apply $_action to ${_selected.length} devices? Remote Helper access may be interrupted. Agent remains available.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))],
      ));
      if (confirmed != true) return;
    }
    final client = await _connection();
    if (_action == 'install') {
    final uploaded = await client.call('package', file: File(package!.path));
    if (uploaded['sha256'] != package.sha256 || uploaded['version'] != package.version || uploaded['productCode'] != package.productCode) {
      setState(() => _status = 'The selected MSI changed during upload. Browse it again.'); return;
    }
    }
    final result = await client.call('jobs', body: {'action': _action, 'sha256': package?.sha256 ?? '', 'deviceIds': _selected.toList()});
    final rows = result['results'] as List;
    final queued = rows.where((row) => row['queued'] == true).length;
    await _refresh();
    if (mounted) setState(() => _status = '$queued $_action jobs queued; ${rows.length - queued} busy/revoked or need Agent 1.1. Offline devices execute when they reconnect.');
  }
  Future<void> _copyCode() async {
    final result = await (await _connection()).call('enrollment', body: {'name': _label.text.trim().isEmpty ? 'Device' : _label.text.trim()});
    await Clipboard.setData(ClipboardData(text: base64.encode(utf8.encode(jsonEncode(result)))));
    if (mounted) setState(() => _status = 'One-device registration code copied (24 hours). Paste into Agent Settings on the target and click Apply registration code, then Save & connect. Treat the code as a password.');
  }
  Future<void> _loadHistory() async {
    final result = await (await _connection()).call('history');
    if (mounted) setState(() => _history = (result['history'] as List).cast<Map<String, dynamic>>());
  }
  Future<void> _cancel(String id) async { await (await _connection()).call('cancel', body: {'deviceId': id}); await _refresh(); }
  Future<void> _revoke(String id) async {
    await (await _connection()).call('revoke', body: {'deviceId': id});
    _selected.remove(id); await _refresh();
  }
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Agent devices — outbound HTTPS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Domain devices can use direct WinRM deployment when remoting, certificates, firewall and administrator access are configured. Agent devices connect to this Deploy computer over outbound HTTPS 443.'),
          const SizedBox(height: 16),
          TextField(controller: _host, enabled: !_busy, decoration: const InputDecoration(labelText: 'Stable DNS name or IPv4 address of this Deploy computer')),
          DropdownButton<String>(hint: const Text('Select LAN address/interface for Agent connections'), value: _lanAddress.text.isEmpty ? null : _lanAddress.text, items: _addresses.map((address) => DropdownMenuItem(value: address, child: Text(address))).toList(), onChanged: _busy ? null : (address) => setState(() => _lanAddress.text = address ?? '')),
          Wrap(spacing: 12, children: [
            OutlinedButton(onPressed: _busy ? null : () => _run(_initialize), child: const Text('Initialize local management server')),
            OutlinedButton(onPressed: _busy ? null : () => _run(_refresh), child: const Text('Refresh devices')),
          ]),
          TextField(controller: _label, enabled: !_busy, decoration: const InputDecoration(labelText: 'Device enrollment label')),
          TextField(controller: _count, enabled: !_busy, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enrollment files to export (one per device)')),
          Wrap(spacing: 12, children: [OutlinedButton(onPressed: _busy ? null : () => _run(_enrollment), child: const Text('Export Agent EXE + enrollment files')), OutlinedButton(onPressed: _busy ? null : () => _run(_copyCode), child: const Text('Copy one-device registration code'))]),
          const Text('Open Agent EXE on the target. Its Settings allow changing the server, importing enrollment or pasting a registration code, testing HTTPS and Save & connect. No PowerShell or Agent MSI required. Update old Agents by running the new EXE and Save & connect (leave token blank to preserve identity).'),
          const SizedBox(height: 16),
          Text(_package == null ? 'Browse the Helper MSI version to deploy.' : 'Selected Helper ${_package!.version}: ${_package!.path}'),
          DropdownButton<String>(value: _action, onChanged: _busy ? null : (value) => setState(() => _action = value!), items: const [
            DropdownMenuItem(value: 'install', child: Text('Install / upgrade selected Helper MSI')),
            DropdownMenuItem(value: 'repair', child: Text('Repair installed Helper')),
            DropdownMenuItem(value: 'uninstall', child: Text('Uninstall Helper')),
            DropdownMenuItem(value: 'start', child: Text('Start Helper service')),
            DropdownMenuItem(value: 'stop', child: Text('Stop Helper service')),
            DropdownMenuItem(value: 'restart', child: Text('Restart Helper service')),
          ]),
          Wrap(spacing: 12, children: [
            OutlinedButton(onPressed: _busy ? null : () => _run(_browse), child: const Text('Browse Helper MSI')),
            OutlinedButton(onPressed: _busy ? null : () => setState(() => _selected.addAll(_devices.where((d) => d['revoked'] != true).map((d) => d['id'] as String))), child: const Text('Select all devices')),
            OutlinedButton(onPressed: _busy ? null : () => setState(_selected.clear), child: const Text('Clear selection')),
            ElevatedButton(onPressed: _busy || (_action == 'install' && _package == null) || _selected.isEmpty ? null : () => _run(_deploy), child: Text('Queue $_action on ${_selected.length} selected')),
            OutlinedButton(onPressed: _busy ? null : () => _run(_loadHistory), child: const Text('Refresh task history')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          SelectableText(_status),
          for (final device in _devices)
            CheckboxListTile(
              value: _selected.contains(device['id']),
              onChanged: _busy || device['revoked'] == true ? null : (selected) => setState(() { if (selected == true) { _selected.add(device['id'] as String); } else { _selected.remove(device['id']); } }),
              title: Text('${device['name']} — ${device['machine']} — ${device['online'] == true ? 'Online' : 'Offline'}'),
              subtitle: Text('${device['status']} | Helper ${device['helperVersion'] ?? 'unknown'} (${device['helperService'] ?? 'unknown'}) | Agent ${device['agentVersion'] ?? '1.0'} | Last seen ${device['lastSeenUtc']}\n${device['message'] ?? ''}'),
              secondary: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Cancel queued job', icon: const Icon(Icons.cancel_outlined), onPressed: _busy || device['job'] == null ? null : () => _run(() => _cancel(device['id'] as String))),
                IconButton(tooltip: 'Revoke Agent access', icon: const Icon(Icons.block), onPressed: _busy || device['revoked'] == true ? null : () => _run(() => _revoke(device['id'] as String))),
              ]),
            ),
          if (_history.isNotEmpty) const Text('Recent task history (latest 200)'),
          for (final entry in _history) ListTile(title: Text('${entry['job']['action'] ?? 'install'} — ${entry['ok'] == true ? 'Succeeded' : 'Failed / cancelled'}'), subtitle: Text('${entry['deviceId']} | ${entry['finishedUtc']}\n${entry['message']}')),
        ]),
      ),
    ),
  );
}
