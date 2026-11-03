import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/remote_helper_deployment.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:window_manager/window_manager.dart';
import 'agent_management_page.dart';

class RemoteDeploymentPage extends StatefulWidget {
  const RemoteDeploymentPage({super.key});
  @override
  State<RemoteDeploymentPage> createState() => _RemoteDeploymentPageState();
}

class _RemoteDeploymentPageState extends State<RemoteDeploymentPage>
    with WindowListener {
  final _targets = TextEditingController();
  final _range = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _parallel = TextEditingController(text: '20');
  final _msi = TextEditingController();
  final _unattended = TextEditingController();
  final _confirm = TextEditingController();
  final _connections = <String, RemoteHelperDeploymentResult>{};
  final _results = <String, RemoteHelperDeploymentResult>{};
  DeploymentAccountType _account = DeploymentAccountType.local;
  HelperMsiPackage? _package;
  bool _prepareHttps = true, _busy = false, _stop = false, _configure = false;
  int? _tested;
  String _status = '';
  String _action = 'install';
  int get _signature =>
      Object.hash(_targets.text, _user.text, _password.text, _account, _prepareHttps);
  bool get _current => _tested == _signature;
  List<String> get _ready => parseDeploymentTargets(
    _targets.text,
  ).where((t) => _connections[t]?.succeeded == true).toList();
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    for (final c in [_targets, _user, _password]) {
      c.addListener(_invalidate);
    }
  }

  void _invalidate() {
    if (mounted) setState(() => _tested = null);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    for (final c in [
      _targets,
      _range,
      _user,
      _password,
      _parallel,
      _msi,
      _unattended,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    if (_busy) return;
    gFFI.close();
    windowManager.setPreventClose(false);
    windowManager.close();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    bool secret = false,
    int lines = 1,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      enabled: !_busy,
      obscureText: secret,
      enableSuggestions: !secret,
      autocorrect: !secret,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 7,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
  Widget _rows(Map<String, RemoteHelperDeploymentResult> rows) => Column(
    children: [
      for (final e in rows.entries)
        ListTile(
          dense: true,
          leading: Icon(
            e.value.succeeded ? Icons.check_circle : Icons.error_outline,
            color: e.value.succeeded ? Colors.green : Colors.red,
          ),
          title: Text(e.key),
          subtitle: Text(e.value.message),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => DragToResizeArea(
    resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
    enableResizeEdges: windowManagerEnableResizeEdges,
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deploy SubnetDesk MSI',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AgentManagementPage()),
              ),
              icon: const Icon(Icons.dns),
              label: const Text('Manage Agent devices (no WinRM required)'),
            ),
            const Text(
              'Add devices, test connectivity and credentials, then deploy your selected Helper version.',
            ),
            const SizedBox(height: 16),
            _field(
              _targets,
              'Target devices',
              hint: 'One hostname or IP per line',
              lines: 3,
            ),
            _field(
              _range,
              'Subnet or IP range',
              hint: '192.168.50.0/24 or 192.168.50.10-192.168.50.200',
            ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _addRange,
                  child: const Text('Add subnet / range'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _import,
                  child: const Text('Import device list'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              _parallel,
              'Simultaneous operations',
              hint:
                  'All devices are queued; choose how many run at the same time',
            ),
            DropdownButtonFormField<DeploymentAccountType>(
              initialValue: _account,
              decoration: const InputDecoration(
                labelText: 'Administrator account type',
              ),
              items: const [
                DropdownMenuItem(
                  value: DeploymentAccountType.local,
                  child: Text('Local account on target'),
                ),
                DropdownMenuItem(
                  value: DeploymentAccountType.qualified,
                  child: Text('Domain / qualified account'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _account = value!;
                      _tested = null;
                    }),
            ),
            const SizedBox(height: 12),
            _field(
              _user,
              'Administrator username',
              hint:
                  r'user or TARGET-PC\user; domain: DOMAIN\user / user@domain',
            ),
            const Text(
              'Local account means a user on the target computer. For an IP target you can enter TARGET-PC\\user explicitly. Use the Windows password, not a Hello PIN.',
            ),
            const SizedBox(height: 12),
            _field(_password, 'Administrator password', secret: true),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _prepareHttps,
              title: const Text('Prepare target HTTPS listener if unavailable'),
              subtitle: const Text(
                'Deployment always uses https://target:5986/wsman. Setup requires existing Kerberos remoting with a DNS name and domain credentials. Creates a server certificate, trusts it for this Windows user, and opens 5986 for the local subnet on private/domain networks. Workgroup/IP targets require local or GPO provisioning and certificate trust first.',
              ),
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _prepareHttps = value ?? false;
                      _tested = null;
                    }),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.network_check),
              label: const Text('1. Test connections'),
            ),
            if (_connections.isNotEmpty && !_current && !_busy)
              const Text('Inputs changed — test connections again.'),
            _rows(_connections),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _field(_msi, 'Helper MSI package', readOnly: true),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _browse,
                  child: const Text('Browse'),
                ),
              ],
            ),
            if (_package != null)
              Text('Selected Helper version: ${_package!.version}'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _configure,
              title: const Text('Configure unattended access'),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _configure = value ?? false),
            ),
            if (_configure) ...[
              _field(_unattended, 'Unattended password', secret: true),
              _field(_confirm, 'Confirm unattended password', secret: true),
            ],
            Text(_status),
            _rows(_results),
            DropdownButton<String>(value: _action, onChanged: _busy ? null : (value) => setState(() => _action = value!), items: const [
              DropdownMenuItem(value: 'install', child: Text('Install / upgrade selected Helper MSI')),
              DropdownMenuItem(value: 'repair', child: Text('Repair installed Helper')),
              DropdownMenuItem(value: 'uninstall', child: Text('Uninstall Helper')),
              DropdownMenuItem(value: 'start', child: Text('Start Helper service')),
              DropdownMenuItem(value: 'stop', child: Text('Stop Helper service')),
              DropdownMenuItem(value: 'restart', child: Text('Restart Helper service')),
            ]),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? () => setState(() => _stop = true)
                      : windowManager.close,
                  child: Text(_busy ? 'Stop pending devices' : 'Close'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _busy ||
                          !_current ||
                          !_connections.values.any((r) => r.succeeded)
                      ? null
                      : _deploy,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.install_desktop),
                  label: Text('2. Run $_action on ready devices'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  void _addRange() {
    try {
      final addresses = expandDeploymentRange(_range.text);
      _targets.text = parseDeploymentTargets(
        '${_targets.text}\n${addresses.join('\n')}',
      ).join('\n');
      showToast(
        '${addresses.length} addresses added. Test connections before deployment.',
      );
    } on FormatException catch (e) {
      showToast(e.message);
    }
  }

  Future<void> _import() async {
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'csv'],
    );
    final file = pick?.files.single.path;
    if (file == null) return;
    try {
      final text = await File(file).readAsString();
      if (mounted)
        _targets.text = parseDeploymentTargets(
          '${_targets.text}\n$text',
        ).join('\n');
    } catch (_) {
      showToast('Could not read the device list.');
    }
  }

  Future<void> _browse() async {
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['msi'],
    );
    final file = pick?.files.single.path;
    if (file == null) return;
    try {
      final package = await HelperMsiPackage.inspect(file);
      if (mounted)
        setState(() {
          _package = package;
          _msi.text = file;
        });
    } catch (_) {
      showToast('Select a valid SubnetDesk Helper MSI.');
    }
  }

  Future<void> _test() async {
    List<String> targets;
    try {
      targets = parseDeploymentTargets(_targets.text);
    } on FormatException catch (e) {
      showToast(e.message);
      return;
    }
    final count = int.tryParse(_parallel.text);
    if (targets.isEmpty ||
        _user.text.trim().isEmpty ||
        _password.text.isEmpty ||
        count == null ||
        count < 1) {
      showToast(
        'Enter targets, credentials and a positive simultaneous count.',
      );
      return;
    }
    final signature = _signature;
    final requests = targets
        .map(
          (t) => RemoteHelperDeploymentRequest(
            target: t,
            username: _user.text,
            administratorPassword: _password.text,
            msiPath: '',
            accountType: _account,
            prepareHttps: _prepareHttps,
            testOnly: true,
          ),
        )
        .toList();
    setState(() {
      _busy = true;
      _stop = false;
      _tested = null;
      _connections.clear();
      _results.clear();
      _status = 'Testing online status, WinRM and credentials...';
    });
    await BulkHelperDeployment().run(
      requests,
      PowerShellRemotingHelperDeployer(),
      concurrency: count,
      cancelled: () => _stop,
      onResult: (target, result) {
        if (mounted) setState(() => _connections[target] = result);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _tested = signature;
      _status =
          '${_connections.values.where((r) => r.succeeded).length} of ${targets.length} ready. Deployment has not started.';
    });
  }

  Future<void> _deploy() async {
    if (!_current) {
      showToast('Test connections first.');
      return;
    }
    final targets = _ready;
    final count = int.tryParse(_parallel.text);
    if (count == null || count < 1 || targets.isEmpty) return;
    if (_action == 'uninstall' || _action == 'stop') {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('Confirm $_action'), content: Text('Apply $_action to ${targets.length} devices? Remote Helper access may be interrupted.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))]));
      if (confirmed != true) return;
    }
    if (_action == 'install' && _configure &&
        (_unattended.text.isEmpty || _unattended.text != _confirm.text)) {
      showToast('Enter matching unattended access passwords.');
      return;
    }
    setState(() => _busy = true);
    HelperMsiPackage? package;
    try {
      if (_action == 'install') package = await HelperMsiPackage.inspect(_msi.text);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      showToast('Browse for a valid Helper MSI.');
      return;
    }
    final requests = targets
        .map(
          (t) => RemoteHelperDeploymentRequest(
            target: t,
            username: _user.text,
            administratorPassword: _password.text,
            msiPath: _msi.text,
            package: package,
            action: _action,
            accountType: _account,
            prepareHttps: false,
            configureUnattended: _configure,
            unattendedPassword: _unattended.text,
          ),
        )
        .toList();
    _password.clear();
    _unattended.clear();
    _confirm.clear();
    setState(() {
      _stop = false;
      _results.clear();
      _status = 'Running $_action ${package?.version ?? ''}...';
    });
    await BulkHelperDeployment().run(
      requests,
      PowerShellRemotingHelperDeployer(),
      concurrency: count,
      cancelled: () => _stop,
      onResult: (target, result) {
        if (mounted) setState(() => _results[target] = result);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      final ok = _results.values.where((r) => r.succeeded).length;
      _status =
          '$ok succeeded, ${_results.length - ok} failed, ${targets.length - _results.length} skipped.';
    });
  }
}
