import 'dart:async';
import 'package:flutter/material.dart';
import '../agent_management.dart';

class AgentRolloutPage extends StatefulWidget {
  const AgentRolloutPage({super.key, required this.connect, required this.onRequests});
  final Future<AgentManagementClient> Function() connect;
  final VoidCallback onRequests;
  @override
  State<AgentRolloutPage> createState() => _AgentRolloutPageState();
}

class _AgentRolloutPageState extends State<AgentRolloutPage> {
  final _ranges = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _profileName = TextEditingController();
  final _search = TextEditingController();
  final _parallel = TextEditingController(text: '20');
  final _selected = <String>{};
  List<Map<String, dynamic>> _devices = [], _profiles = [], _schedules = [], _jobs = [], _subnets = [];
  String? _profile, _editingProfile, _error;
  String _account = 'local';
  bool _busy = false, _loading = false, _ascending = true, _showPassword = false;
  int _sort = 0, _page = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }
  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_ranges, _username, _password, _profileName, _search, _parallel]) { c.clear(); c.dispose(); }
    super.dispose();
  }
  Future<Map<String, dynamic>> _call(String route, [Object? body]) async =>
      (await widget.connect()).call('rollout/$route', body: body);
  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.map((v) => Map<String, dynamic>.from(v as Map)).toList() : [];
  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await _call('status');
      if (mounted) setState(() {
        _devices = _rows(data['devices']).where((d) => d['verifiedWindows'] == true).toList();
        _profiles = _rows(data['profiles']); _schedules = _rows(data['schedules']); _jobs = _rows(data['jobs']);
        if (!_profiles.any((p) => p['id'].toString() == _profile)) {
          _profile = _profiles.isEmpty ? null : _profiles.first['id'].toString();
        }
        _selected.retainAll(_devices.map((d) => d['id'].toString()));
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Agent deployment could not load. Update Deploy and verify its management service is running.');
    } finally { _loading = false; }
  }
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await action(); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Map<String, dynamic> _plan(String kind) {
    if (_profile == null) throw const FormatException('Save or select administrator credentials first.');
    final parallel = int.tryParse(_parallel.text);
    if (parallel == null || parallel < 1 || parallel > 128) throw const FormatException('Simultaneous operations must be 1–128; all other devices remain queued.');
    if (kind == 'push' && _selected.isEmpty) throw const FormatException('Select verified Windows devices first.');
    return {'profileId': _profile, 'parallelism': parallel,
      if (kind == 'discover') 'ranges': _ranges.text,
      if (kind == 'push') 'deviceIds': _selected.toList()};
  }
  Future<bool> _confirm(String title, String message) async => await showDialog<bool>(
      context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
      ])) == true;
  Future<void> _saveProfile() async {
    final name = _profileName.text.trim().isEmpty ? _username.text.trim().replaceFirst(r'.\', '') : _profileName.text.trim();
    if (_profiles.any((p) => p['id'].toString() != _editingProfile && p['name'].toString().trim().toLowerCase() == name.toLowerCase())) {
      throw const FormatException('A credential profile with this name already exists. Choose another name or edit that profile.');
    }
    final body = {if (_editingProfile != null) 'id': _editingProfile!, 'name': _profileName.text, 'username': _username.text,
      'password': _password.text, 'accountType': _account};
    try {
      final saved = await _call('profile', body);
      if (mounted) { setState(() {
        _profiles.removeWhere((p) => p['id'] == saved['id']); _profiles.add(saved); _profile = saved['id'].toString();
        _clearProfileEditor();
      }); }
      await _load();
    } finally { body['password'] = ''; if (mounted) setState(() { _password.clear(); _showPassword = false; }); }
  }
  void _clearProfileEditor() {
    _editingProfile = null; _profileName.clear(); _username.clear(); _password.clear(); _showPassword = false;
  }
  void _editProfile() {
    final saved = _profiles.firstWhere((p) => p['id'].toString() == _profile);
    setState(() {
      _editingProfile = _profile; _profileName.text = saved['name'].toString();
      _username.text = saved['username'].toString(); _account = saved['accountType'].toString();
      _password.clear(); _showPassword = false;
    });
  }
  Future<void> _deleteProfile() async {
    final id = _profile;
    final saved = _profiles.firstWhere((p) => p['id'].toString() == id);
    if (!await _confirm('Delete credential profile?', 'Delete "${saved['name']}" and its saved credentials? Profiles used by queued/running jobs or schedules cannot be deleted.')) return;
    await _call('profile-delete', {'id': id});
    if (mounted) setState(() {
      _profiles.removeWhere((p) => p['id'].toString() == id); _profile = null;
      if (_editingProfile == id) _clearProfileEditor();
    });
    await _load();
  }
  Future<void> _queue(String kind) async {
    final plan = _plan(kind);
    if (kind == 'push' && !await _confirm('Push Agent to ${_selected.length} Windows devices?',
        'The management service will verify each Windows identity, copy Agent over the administrator share and run silent setup. Existing same-server registrations are preserved. Review new requests under Agent requests.')) return;
    await _call(kind, plan); await _load();
  }
  Future<void> _schedule(String kind) async {
    final plan = _plan(kind);
    final name = TextEditingController(text: kind == 'discover' ? 'Windows discovery' : 'Agent deployment');
    final interval = TextEditingController(text: '1440');
    var first = DateTime.now().add(const Duration(days: 1));
    String? error;
    try {
      final route = DialogRoute<bool>(context: context, builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(title: Text(kind == 'discover' ? 'Schedule discovery' : 'Schedule Agent push'),
          content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(kind == 'discover' ? 'Discover the entered VLAN/subnet ranges using the saved credential profile.'
                : 'Deploy only to the ${_selected.length} selected Windows identities. Newly discovered devices are not automatically added.'),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Schedule name')),
            TextField(controller: interval, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Repeat every (minutes)', helperText: '60 = hourly · 1440 = daily · 10080 = weekly')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: first,
                  firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(first));
              if (time != null) update(() => first = DateTime(date.year, date.month, date.day, time.hour, time.minute));
            }, child: Text('First run (local): ${first.toLocal().toString().substring(0, 16)}')),
            const Text('Runs in the management service while Deploy is closed. Missed times coalesce; overlapping runs are not duplicated.'),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          ])), actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final minutes = int.tryParse(interval.text);
              if (minutes == null || minutes < 5 || minutes > 525600 || !first.isAfter(DateTime.now())) {
                update(() => error = 'Choose a future first run and an interval of 5 minutes–365 days.'); return;
              }
              Navigator.pop(context, true);
            }, child: const Text('Save schedule')),
          ])));
      final confirmed = await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
      if (confirmed == true) {
        await _call('schedule', {...plan, 'kind': kind, 'name': name.text,
          'nextRunUtc': first.toUtc().toIso8601String(), 'intervalMinutes': int.parse(interval.text)});
        await _load();
      }
    } finally { name.dispose(); interval.dispose(); }
  }
  Widget _panel(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 14), child,
    ])));
  Widget _field(TextEditingController c, String label, {bool secret = false}) => SizedBox(width: 260,
    child: TextField(controller: c, obscureText: secret && !_showPassword, enableSuggestions: !secret,
      autocorrect: false, onChanged: c == _search ? (_) => setState(() => _page = 0) : null,
      decoration: InputDecoration(labelText: label, suffixIcon: secret ? IconButton(
        tooltip: _showPassword ? 'Hide password' : 'Show password',
        onPressed: () => setState(() => _showPassword = !_showPassword),
        icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)) : null)));
  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    const columns = ['machine', 'target', 'windowsVersion', 'agentService', 'verifiedUtc', 'pushStatus'];
    final filtered = _devices.where((d) => '${d['machine']} ${d['target']} ${d['windowsVersion']}'.toLowerCase().contains(query)).toList()
      ..sort((a, b) => (a[columns[_sort]] ?? '').toString().compareTo((b[columns[_sort]] ?? '').toString()) * (_ascending ? 1 : -1));
    final pages = (filtered.length / 25).ceil().clamp(1, 100000);
    final page = _page.clamp(0, pages - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Agent deployment', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('Discover Windows computers across entered VLANs, test administrator access, then install Agent silently. WMI/RPC and SMB ADMIN\$ access must already be allowed on targets. No WinRM listener is required.'),
      const SizedBox(height: 8),
      const Text('Only authenticated Windows results appear below. Offline, non-Windows and unverified candidates are excluded; a closed port alone never identifies an operating system.'),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: SelectableText(_error!, style: const TextStyle(color: Colors.red))),
      if (_busy) const LinearProgressIndicator(),
      _panel('1. Manage credentials', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_profiles.isNotEmpty) DropdownButtonFormField<String>(value: _profile, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Saved credential profile'),
          items: _profiles.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text('${p['name']} · ${p['accountType']} · ${p['username']}'))).toList(),
          onChanged: _busy ? null : (v) => setState(() => _profile = v)),
        if (_profiles.isNotEmpty) Wrap(spacing: 8, children: [
          TextButton.icon(onPressed: _busy || _profile == null ? null : _editProfile,
            icon: const Icon(Icons.edit_outlined), label: const Text('Edit selected profile')),
          IconButton(tooltip: 'Delete selected profile', onPressed: _busy || _profile == null ? null : () => _run(_deleteProfile),
            icon: const Icon(Icons.delete_outline)),
        ]),
        if (_editingProfile != null) Text('Editing: ${_profileName.text} · Leave password blank to keep it when the account is unchanged.'),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 12, children: [
          SizedBox(width: 230, child: DropdownButtonFormField<String>(value: _account, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Account type'), items: const [
              DropdownMenuItem(value: 'local', child: Text('Local administrator')),
              DropdownMenuItem(value: 'domain', child: Text('Domain administrator'))],
            onChanged: _busy ? null : (v) => setState(() => _account = v!))),
          _field(_profileName, 'Profile name'),
          _field(_username, _account == 'local' ? 'Local account name (e.g. Administrator)' : 'DOMAIN\\user or user@domain'),
          _field(_password, 'Windows password', secret: true),
          FilledButton(onPressed: _busy ? null : () => _run(_saveProfile), child: Text(_editingProfile == null ? 'Save credential profile' : 'Update credential profile')),
          if (_editingProfile != null) TextButton(onPressed: _busy ? null : () => setState(_clearProfileEditor), child: const Text('New profile')),
        ]),
        const SizedBox(height: 10),
        const Text('Saved credentials are encrypted with Windows DPAPI on the management server so schedules can run unattended. Passwords are not returned to the dashboard or placed in process arguments. Local remote-UAC restrictions may still deny access.'),
      ])),
      _panel('2. IP pools / VLAN discovery', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _ranges, minLines: 3, maxLines: 7, decoration: const InputDecoration(
          labelText: 'VLAN/subnet ranges or hostnames — one per line',
          hintText: '192.168.50.0/24\n192.168.60.10-192.168.60.200\nPC-FINANCE-01')),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton(onPressed: _busy ? null : () => _run(() async {
            final data = await _call('subnets'); if (mounted) setState(() => _subnets = _rows(data['subnets']));
          }), child: const Text('Suggest connected subnets')),
          SizedBox(width: 210, child: TextField(controller: _parallel, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Simultaneous operations'))),
          FilledButton(onPressed: _busy ? null : () => _run(() => _queue('discover')), child: const Text('Discover Windows / test credentials')),
          OutlinedButton(onPressed: _busy ? null : () => _run(() => _schedule('discover')), child: const Text('Schedule discovery')),
        ]),
        Wrap(spacing: 8, children: _subnets.map((s) => ActionChip(label: Text('${s['range']} · ${s['adapter']}'),
          onPressed: () => setState(() => _ranges.text = '${_ranges.text.trim()}\n${s['range']}'.trim()))).toList()),
        const Text('Suggestions cover connected interfaces, not the organization’s complete VLAN topology. Add routed VLAN ranges explicitly. Up to 65,536 candidate addresses per job; all are queued, independent of concurrency.'),
      ])),
      _panel('3. Verified Windows computers', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 10, runSpacing: 8, children: [
          _field(_search, 'Search Windows computers'),
          TextButton(onPressed: () => setState(() => _selected.addAll(filtered.where((d) => d['uuid'] != '').map((d) => d['id'].toString()))), child: Text('Select all ${filtered.length} results')),
          TextButton(onPressed: () => setState(_selected.clear), child: const Text('Clear selection')),
          FilledButton(onPressed: _busy || _selected.isEmpty ? null : () => _run(() => _queue('push')), child: Text('Push Agent to ${_selected.length} selected')),
          OutlinedButton(onPressed: _busy || _selected.isEmpty ? null : () => _run(() => _schedule('push')), child: const Text('Schedule push')),
          TextButton(onPressed: widget.onRequests, child: const Text('Review Agent requests')),
        ]),
        const Text('A push rechecks Windows identity before writing. Devices without a hardware UUID are displayed but cannot be pushed. Installer success and service startup are distinct from server approval.'),
        if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No verified Windows computers yet. Save credentials and run discovery.')),
        if (filtered.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          sortColumnIndex: _sort, sortAscending: _ascending,
          columns: [for (var i = 0; i < columns.length; i++) DataColumn(label: Text(['Computer', 'Address', 'Windows version', 'Agent service', 'Last verified (UTC)', 'Push result'][i]),
            onSort: (index, ascending) => setState(() { _sort = index; _ascending = ascending; }))],
          rows: filtered.skip(page * 25).take(25).map((d) => DataRow(selected: _selected.contains(d['id']),
            onSelectChanged: d['uuid'] == '' ? null : (v) => setState(() { if (v == true) _selected.add(d['id'].toString()); else _selected.remove(d['id']); }),
            cells: columns.map((c) => DataCell(Tooltip(message: d['message']?.toString() ?? '', child: Text((d[c] ?? '').toString())))).toList())).toList())),
        Row(children: [Text('${filtered.length} Windows devices · page ${page + 1} of $pages'),
          IconButton(onPressed: page > 0 ? () => setState(() => _page = page - 1) : null, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: page + 1 < pages ? () => setState(() => _page = page + 1) : null, icon: const Icon(Icons.chevron_right)),
          TextButton(onPressed: _load, child: const Text('Refresh'))]),
      ])),
      _panel('Discovery and push schedules', Column(children: [
        if (_schedules.isEmpty) const Text('No schedules. Discovery and push have independent first-run times and repeat intervals.'),
        for (final s in _schedules) ListTile(title: Text('${s['name']} · ${s['kind']}'),
          subtitle: Text('Every ${s['intervalMinutes']} minutes · next UTC ${s['nextRunUtc']}'),
          trailing: Switch(value: s['enabled'] == 'True', onChanged: _busy ? null : (v) => _run(() async {
            await _call('schedule-toggle', {'id': s['id'], 'enabled': v}); await _load();
          }))),
      ])),
      _panel('Deployment jobs', Column(children: [
        if (_jobs.isEmpty) const Text('No discovery or push jobs yet.'),
        for (final j in _jobs) ListTile(title: Text('${j['kind']} · ${j['state']} · ${j['completed']}/${j['total']} checked · ${j['failed']} failed/unverified · ${j['windows']} Windows'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(j['message']?.toString() ?? ''),
            for (final failure in _rows(j['failures'])) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${failure['count']} targets: ${failure['message']}\nExamples: ${(failure['targets'] as List).join(', ')}'),
            ),
          ]),
          trailing: ['queued', 'running'].contains(j['state']) ? TextButton(onPressed: _busy ? null : () => _run(() async {
            await _call('cancel', {'id': j['id']}); await _load();
          }), child: const Text('Stop after current targets')) : null),
      ])),
    ]);
  }
}
