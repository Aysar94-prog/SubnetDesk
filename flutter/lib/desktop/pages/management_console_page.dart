import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../agent_management.dart';
import '../management_models.dart';
import '../device_inventory_table.dart';
import '../remote_helper_deployment.dart';
import 'agent_rollout_page.dart';

const _ink = Color(0xFF172B4D);
const _muted = Color(0xFF65758B);
const _accent = Color(0xFF087F8C);
const _border = Color(0xFFE3E9F1);
const _canvas = Color(0xFFF3F6FA);

class ManagementConsolePage extends StatefulWidget {
  const ManagementConsolePage({
    super.key,
    this.connect,
    this.rememberTable = true,
    this.tablePreferences,
    this.initialHelperPackage,
  });
  final Future<AgentManagementClient> Function()? connect;
  final bool rememberTable;
  final DeviceTablePreferences? tablePreferences;
  final HelperMsiPackage? initialHelperPackage;
  @override
  State<ManagementConsolePage> createState() => _ManagementConsolePageState();
}

class _ManagementConsolePageState extends State<ManagementConsolePage>
    with WindowListener {
  AgentManagementClient? _client;
  DeviceTableSettings _table = DeviceTableSettings();
  late final DeviceTablePreferences _tablePreferences;
  Future<void> _tableSave = Future.value();
  bool _tableChanged = false;
  final _inventoryScroll = ScrollController();
  final _search = TextEditingController();
  final _selected = <String>{};
  final _progress = <String, String>{};
  List<ManagedDevice> _devices = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _library = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _agentPackages = [];
  Map<String, dynamic>? _agentPackage;
  final _requestSelection = <String>{};
  HelperMsiPackage? _package;
  Timer? _timer;
  bool _busy = false, _refreshing = false, _connected = false;
  bool _canStopPending = false, _stopPending = false;
  String _operationLabel = 'Working…';
  String? _error;
  String _transport = 'all', _filter = 'all', _group = '';
  int _section = 0, _page = 0, _pageSize = 25;
  DateTime? _lastSync;
  String _releaseLabel = 'Version unavailable';
  static const _titles = [
    'Overview',
    'Devices',
    'Tasks & history',
    'Helper packages',
    'Server & enrollment',
    'Agent requests',
    'Agent updates',
    'Agent deployment',
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_loadReleaseLabel());
    _package = widget.initialHelperPackage;
    _tablePreferences = widget.tablePreferences ?? DeviceTablePreferences();
    if (widget.rememberTable) unawaited(_loadTable());
    _search.addListener(() {
      if (mounted) setState(() => _page = 0);
    });
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _loadReleaseLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _releaseLabel = 'Deploy ${info.version} · Build ${info.buildNumber}');
    } on PlatformException {
      // Keep an honest unavailable label when Windows metadata cannot be read.
    } on MissingPluginException {
      // The platform plugin is absent in isolated widget environments.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inventoryScroll.dispose();
    _search.dispose();
    _client?.close();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_busy) {
      _notice('An operation is running. Wait for it to finish before closing.');
      return;
    }
    await _tableSave;
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<AgentManagementClient> _connection() async => _client ??=
      await (widget.connect?.call() ?? AgentManagementClient.local());
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final client = await _connection();
      final values = await Future.wait([
        client.call('devices'),
        client.call('history'),
        client.call('packages'),
        client.call('requests'),
        client.call('agent-packages'),
      ]);
      if (!mounted) return;
      setState(() {
        _devices = (values[0]['devices'] as List)
            .map((row) => ManagedDevice(Map<String, dynamic>.from(row as Map)))
            .toList();
        if (_group.isNotEmpty && !_devices.any((d) => d.group == _group))
          _group = '';
        _history = (values[1]['history'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _library = (values[2]['packages'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _requests = ((values[3]['requests'] as List?) ?? [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _agentPackages = ((values[4]['packages'] as List?) ?? [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _requestSelection.removeWhere(
          (id) => !_requests.any((r) => r['id'] == id),
        );
        _selected.removeWhere(
          (id) => !_devices.any((d) => d.id == id && !d.revoked),
        );
        _connected = true;
        _error = null;
        _lastSync = DateTime.now();
      });
    } on FileSystemException {
      if (mounted)
        setState(() {
          _connected = false;
          _error =
              'The management server is not configured or its local settings require administrator access. Open Server & enrollment to set up this computer.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _connected = false;
          _error =
              'The management service could not be reached. Existing device data is shown from the last successful refresh.';
        });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _stopPending = false;
      _operationLabel = 'Working…';
    });
    try {
      await action();
    } on FormatException catch (error) {
      _notice(error.message);
    } on HttpException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice(
        'Operation failed. Check the server connection, administrator access and service logs.',
      );
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _canStopPending = false;
        });
    }
  }

  List<ManagedDevice> get _filtered => sortManagedInventory(
    filterManagedDevices(
      _devices,
      query: _search.text,
      transport: _transport,
      status: _filter,
      group: _group,
    ),
    _table.sort,
    _table.ascending,
  );

  Future<void> _loadTable() async {
    try {
      final settings = await _tablePreferences.load();
      if (mounted && !_tableChanged) setState(() => _table = settings);
    } catch (_) {
      _notice(
        'Table preferences could not be loaded. Default columns are shown.',
      );
    }
  }

  void _setTable(DeviceTableSettings settings) {
    setState(() {
      _tableChanged = true;
      _table = settings;
      _page = 0;
    });
    if (widget.rememberTable) {
      _tableSave = _tableSave
          .then((_) => _tablePreferences.save(settings))
          .catchError((Object error) {
            _notice('Column preferences could not be saved on this computer.');
          });
    }
  }

  Future<void> _chooseColumns() async {
    var visible = _table.visible.toSet();
    final accepted = await _modal<bool>(
      StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Visible columns'),
          content: SizedBox(
            width: 430,
            height: 480,
            child: Column(
              children: [
                const Text(
                  'Choose the details shown in the device table. Click any column heading to sort in either direction.',
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => update(
                        () => visible = InventoryColumn.values.toSet(),
                      ),
                      child: const Text('Show all'),
                    ),
                    TextButton(
                      onPressed: () => update(
                        () => visible = DeviceTableSettings.defaults.toSet(),
                      ),
                      child: const Text('Reset defaults'),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final column in InventoryColumn.values)
                        CheckboxListTile(
                          key: ValueKey('column-choice-${column.name}'),
                          title: Text(column.label),
                          value: visible.contains(column),
                          onChanged:
                              visible.length == 1 && visible.contains(column)
                              ? null
                              : (checked) => update(() {
                                  if (checked == true) {
                                    visible.add(column);
                                  } else {
                                    visible.remove(column);
                                  }
                                }),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply columns'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final sort = visible.contains(_table.sort)
        ? _table.sort
        : InventoryColumn.values.firstWhere(visible.contains);
    _setTable(
      DeviceTableSettings(
        visible: visible,
        sort: sort,
        ascending: sort == _table.sort ? _table.ascending : true,
      ),
    );
  }

  String _time(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Never';
    final delta = DateTime.now().difference(date);
    if (delta.inSeconds < 60) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
  Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(22)}) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(padding: padding, child: child),
      );
  Widget _heading(String title, String subtitle, {Widget? trailing}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
  Widget _button(
    String text,
    IconData icon,
    VoidCallback? onTap, {
    bool primary = false,
  }) => primary
      ? FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          label: Text(text),
        )
      : OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          label: Text(text),
        );
  void _openDevices({String method = 'all', String state = 'all'}) =>
      setState(() {
        _section = 1;
        _transport = method;
        _filter = state;
        _page = 0;
      });

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: _canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        primary: _accent,
        surface: Colors.white,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: _ink,
        displayColor: _ink,
        fontFamily: 'Segoe UI',
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
        ),
        dataTextStyle: TextStyle(fontSize: 12, color: _ink),
        dividerThickness: .7,
      ),
    ),
    child: Builder(
      builder: (context) => Scaffold(
        body: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 1150;
            return Row(
              children: [
                _sidebar(wide),
                Expanded(
                  child: Column(
                    children: [
                      _topbar(),
                      if (_busy) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _operationLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _accent,
                                  ),
                                ),
                              ),
                              if (_canStopPending)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _stopPending = true),
                                  child: Text(
                                    _stopPending
                                        ? 'Stopping unsent work…'
                                        : 'Stop pending work',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(wide ? 28 : 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_error != null) ...[
                                _banner(),
                                const SizedBox(height: 20),
                              ],
                              if (_requests.isNotEmpty && _section != 5) ...[
                                Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.how_to_reg,
                                      color: _accent,
                                    ),
                                    title: Text(
                                      '${_requests.length} computers are waiting for approval',
                                    ),
                                    trailing: TextButton(
                                      onPressed: () =>
                                          setState(() => _section = 5),
                                      child: const Text('Review requests'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              switch (_section) {
                                0 => _overview(),
                                1 => _devicePage(),
                                2 => _taskPage(),
                                3 => _packagePage(),
                                5 => _requestsPage(),
                                6 => _agentUpdatesPage(),
                                7 => AgentRolloutPage(connect: _connection,
                                    onRequests: () => setState(() => _section = 5)),
                                _ => _settingsPage(),
                              },
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget _sidebar(bool wide) {
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.devices_outlined,
      Icons.task_alt_outlined,
      Icons.inventory_2_outlined,
      Icons.settings_outlined,
      Icons.how_to_reg_outlined,
      Icons.system_update_alt,
      Icons.lan_outlined,
    ];
    return Container(
      width: wide ? 224 : 76,
      color: const Color(0xFF102438),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 23 : 18, 29, 16, 32),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Image.asset('assets/deploy_icon.png', semanticLabel: 'SubnetDesk Deploy'),
                ),
                if (wide) ...[
                  const SizedBox(width: 11),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SubnetDesk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'DEPLOY CONSOLE',
                        style: TextStyle(
                          color: Color(0xFF86A2BA),
                          fontSize: 8,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(child: Column(children: [
          for (var i = 0; i < _titles.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 6),
              child: Tooltip(
                message: _titles[i],
                child: Material(
                  color: _section == i
                      ? const Color(0xFF1D3B51)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _section = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icons[i],
                            size: 20,
                            color: _section == i
                                ? const Color(0xFF5DD8D0)
                                : const Color(0xFF8EA9BF),
                          ),
                          if (wide) ...[
                            const SizedBox(width: 13),
                            Text(
                              _titles[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: _section == i
                                    ? Colors.white
                                    : const Color(0xFFB7C8D7),
                                fontWeight: _section == i
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]))),
          if (wide)
            Padding(
              padding: const EdgeInsets.all(23),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFF284359)),
                  const SizedBox(height: 13),
                  const Text(
                    'DEPLOYMENT SERVER',
                    style: TextStyle(
                      color: Color(0xFF7897AF),
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    Platform.localHostname,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Local administrator console',
                    style: TextStyle(color: Color(0xFF7897AF), fontSize: 10),
                  ),
                  const SizedBox(height: 7),
                  SelectableText(_releaseLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _topbar() => Container(
    height: 68,
    padding: const EdgeInsets.only(left: 28, right: 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: DragToMoveArea(
            child: Row(
              children: [
                const Text(
                  'Workspace',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.chevron_right, size: 15, color: _muted),
                ),
                Text(
                  _titles[_section],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        _pill(
          _connected ? 'Server connected' : 'Server unavailable',
          _connected ? const Color(0xFF148368) : const Color(0xFFC27B18),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Refresh inventory',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh, size: 20),
        ),
        const VerticalDivider(indent: 22, endIndent: 22),
        IconButton(
          tooltip: 'Minimize',
          onPressed: () => windowManager.minimize(),
          icon: const Icon(Icons.remove, size: 17),
        ),
        IconButton(
          tooltip: 'Maximize',
          onPressed: () async => await windowManager.isMaximized()
              ? windowManager.unmaximize()
              : windowManager.maximize(),
          icon: const Icon(Icons.crop_square, size: 15),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onWindowClose,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
  Widget _banner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8EA),
      border: Border.all(color: const Color(0xFFF0DEB1)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFFAB741A), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFF85621F)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _section = 4),
          child: const Text('Server settings'),
        ),
      ],
    ),
  );
  Widget _overview() {
    final online = _devices.where((d) => d.online).length;
    final agents = _devices.where((d) => d.isAgent).length;
    final pending = _devices.where((d) => d.hasJob).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Your device fleet, in one place',
          'Inventory, application lifecycle and deployment health across Agent and domain devices.',
          trailing: _button(
            'Add devices',
            Icons.add,
            _busy ? null : _addDevices,
            primary: true,
          ),
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, bounds) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _stat(
                'Total devices',
                '${_devices.length}',
                'Across all management methods',
                Icons.devices_outlined,
                _ink,
                (bounds.maxWidth - 48) / 4,
                () => _openDevices(),
              ),
              _stat(
                'Connected / verified',
                '$online',
                'Agent heartbeat or domain test',
                Icons.check_circle_outline,
                const Color(0xFF148368),
                (bounds.maxWidth - 48) / 4,
                () => _openDevices(state: 'online'),
              ),
              _stat(
                'Needs attention',
                '${_devices.where((d) => d.revoked || d.text('status') == 'Failed').length}',
                'Failed tasks and revoked access',
                Icons.warning_amber_rounded,
                const Color(0xFFD18A25),
                (bounds.maxWidth - 48) / 4,
                () => _openDevices(state: 'attention'),
              ),
              _stat(
                'Active tasks',
                '$pending',
                'Queued or assigned to devices',
                Icons.sync_outlined,
                _accent,
                (bounds.maxWidth - 48) / 4,
                () => setState(() => _section = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panelTitle(
                      'Management coverage',
                      'Two connection methods. One inventory.',
                    ),
                    const SizedBox(height: 25),
                    _coverage(
                      'Agent managed',
                      agents,
                      const Color(0xFF0C9297),
                      'Secure outbound connection · HTTPS 443',
                      () => _openDevices(method: 'agent'),
                    ),
                    const SizedBox(height: 20),
                    _coverage(
                      'Domain / WinRM',
                      _devices.length - agents,
                      const Color(0xFF5275C8),
                      'Direct management · no Agent required',
                      () => _openDevices(method: 'domain'),
                    ),
                    const SizedBox(height: 22),
                    const Divider(color: _border),
                    const SizedBox(height: 12),
                    const Text(
                      'Domain membership does not enable remote management by itself. Verify WinRM HTTPS and administrator access before running tasks.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              flex: 2,
              child: _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panelTitle(
                      'Quick actions',
                      'Manage the fleet from this console.',
                    ),
                    const SizedBox(height: 16),
                    _quick(
                      Icons.person_add_alt_1_outlined,
                      'Enroll Agent devices',
                      'Export one reusable setup, then approve device requests',
                      () => _run(_enroll),
                    ),
                    _quick(
                      Icons.domain_add_outlined,
                      'Add domain computers',
                      'Discover AD or import hostnames',
                      _addDevices,
                    ),
                    _quick(
                      Icons.inventory_2_outlined,
                      'Select Helper release',
                      'Browse and verify your MSI package',
                      () => _run(_browse),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _panelTitle(
                      'Recent activity',
                      'Latest completed and cancelled tasks',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _section = 2),
                    child: const Text('View all tasks'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                _empty(
                  Icons.task_alt,
                  'No completed tasks yet',
                  'Task results appear here after a device reports back.',
                )
              else
                ..._history.take(4).map(_activity),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _lastSync == null
              ? 'Waiting for the first server sync'
              : 'Last synchronized ${_time(_lastSync!.toIso8601String())} · Refreshes every 15 seconds',
          style: const TextStyle(fontSize: 10, color: _muted),
        ),
      ],
    );
  }

  Widget _stat(
    String label,
    String value,
    String detail,
    IconData icon,
    Color color,
    double width,
    VoidCallback tap,
  ) => SizedBox(
    width: width,
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(12),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
                Icon(icon, color: color, size: 19),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 31,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
      ),
    ),
  );
  Widget _panelTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
    ],
  );
  Widget _coverage(
    String title,
    int count,
    Color color,
    String subtitle,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: _devices.isEmpty ? 0 : count / _devices.length,
            minHeight: 7,
            color: color,
            backgroundColor: _canvas,
          ),
        ),
        const SizedBox(height: 7),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ),
      ],
    ),
  );
  Widget _quick(IconData icon, String title, String detail, VoidCallback tap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _canvas,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: _accent),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(fontSize: 10, color: _muted),
        ),
        trailing: const Icon(Icons.chevron_right, color: _muted, size: 18),
        onTap: _busy ? null : tap,
      );
  Widget _empty(IconData icon, String title, String detail) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9CACBD), size: 35),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _horizontalInventory({required Widget child}) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: Scrollbar(
      controller: _inventoryScroll,
      thumbVisibility: true,
      trackVisibility: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _inventoryScroll,
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    ),
  );
  DataCell _inventoryCell(ManagedDevice device, InventoryColumn column) {
    if (column == InventoryColumn.device) return _deviceNameCell(device);
    if (column == InventoryColumn.connection)
      return DataCell(
        _pill(
          _progress[device.id] ?? device.connection,
          device.revoked
              ? _muted
              : device.online
              ? const Color(0xFF148368)
              : const Color(0xFFB47A20),
        ),
      );
    final value = column.value(device);
    final display = column == InventoryColumn.lastSeen
        ? _time(value)
        : column == InventoryColumn.helperVersion
        ? device.version
        : value.isEmpty
        ? 'Not reported'
        : value;
    return DataCell(
      Tooltip(
        message: value.isEmpty ? display : value,
        child: SizedBox(
          width: column.width,
          child: column == InventoryColumn.helperVersion
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      device.text('helperService').isEmpty
                          ? 'Service not reported'
                          : device.text('helperService'),
                      style: const TextStyle(fontSize: 10, color: _muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Text(
                  display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: column == InventoryColumn.management
                        ? _accent
                        : _ink,
                  ),
                ),
        ),
      ),
    );
  }

  DataCell _deviceNameCell(ManagedDevice device) => DataCell(
    SizedBox(
      width: 180,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _canvas,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              device.isAgent
                  ? Icons.desktop_windows_outlined
                  : Icons.domain_outlined,
              size: 18,
              color: _muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  device.address,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    onTap: () => _details(device),
  );
  DataCell _inventoryActions(ManagedDevice device) => DataCell(
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 19),
      onSelected: (action) => _deviceMenu(device, action),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'details', child: Text('Device details')),
        const PopupMenuItem(
          value: 'edit',
          child: Text('Rename / assign group'),
        ),
        if (device.hasJob)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('Cancel queued task'),
          ),
        if (device.isAgent && !device.revoked)
          const PopupMenuItem(
            value: 'revoke',
            child: Text('Revoke Agent access'),
          ),
          PopupMenuItem(
            value: 'remove',
            enabled: !device.hasJob,
            child: const Text('Delete device'),
          ),
      ],
    ),
  );
  Widget _devicePage() {
    final columns = _table.columns;
    final filtered = _filtered;
    final pages = (filtered.length / _pageSize).ceil().clamp(1, 1000000);
    final page = _page.clamp(0, pages - 1);
    final rows = filtered.skip(page * _pageSize).take(_pageSize).toList();
    final groups = _devices.map((d) => d.group).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Devices',
          '${_devices.length} registered devices · Agent and domain computers in a unified inventory.',
          trailing: _button(
            'Add devices',
            Icons.add,
            _busy ? null : _addDevices,
            primary: true,
          ),
        ),
        const SizedBox(height: 22),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in ['all', 'agent', 'domain'])
                    ChoiceChip(
                      label: Text(
                        '${method == 'all'
                            ? 'All devices'
                            : method == 'agent'
                            ? 'Agent managed'
                            : 'Domain / WinRM'}  ${_devices.where((d) => method == 'all' || (method == 'agent') == d.isAgent).length}',
                      ),
                      selected: _transport == method,
                      onSelected: (_) => setState(() {
                        _transport = method;
                        _page = 0;
                      }),
                      showCheckmark: false,
                      selectedColor: const Color(0xFFDDF3F1),
                      side: BorderSide(
                        color: _transport == method
                            ? const Color(0xFF9AD7D3)
                            : _border,
                      ),
                      labelStyle: TextStyle(
                        color: _transport == method ? _accent : _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search name, address or group',
                        prefixIcon: Icon(Icons.search, size: 19),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 155,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Connection',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All states'),
                        ),
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Connected / ready'),
                        ),
                        DropdownMenuItem(
                          value: 'offline',
                          child: Text('Not connected'),
                        ),
                        DropdownMenuItem(
                          value: 'attention',
                          child: Text('Needs attention'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _filter = value!;
                        _page = 0;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 155,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('group-$_group'),
                      initialValue: groups.contains(_group) ? _group : '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Group'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All groups'),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _group = value!;
                        _page = 0;
                      }),
                    ),
                  ),
                  _button(
                    'Export CSV',
                    Icons.download_outlined,
                    _busy ? null : () => _run(_exportDevices),
                  ),
                  _button(
                    'Columns',
                    Icons.view_column_outlined,
                    _busy ? null : _chooseColumns,
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Divider(color: _border),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_selected.length} selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _selected.addAll(
                        filtered.where((d) => !d.revoked).map((d) => d.id),
                      ),
                    ),
                    child: Text('Select all ${filtered.length} results'),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Clear'),
                    ),
                  PopupMenuButton<String>(
                    enabled: !_busy && _connected && _selected.isNotEmpty,
                    onSelected: (action) => _run(() => _execute(action)),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'test',
                        child: Text('Verify domain connections'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'install',
                        child: Text('Install / update Helper'),
                      ),
                      PopupMenuItem(
                        value: 'repair',
                        child: Text('Repair Helper'),
                      ),
                      PopupMenuItem(
                        value: 'uninstall',
                        child: Text('Uninstall Helper'),
                      ),
                      PopupMenuItem(
                        value: 'helper-settings',
                        child: Text('Helper security settings'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'agent-update',
                        child: Text('Update Agent'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'start',
                        child: Text('Start Helper service'),
                      ),
                      PopupMenuItem(
                        value: 'stop',
                        child: Text('Stop Helper service'),
                      ),
                      PopupMenuItem(
                        value: 'restart',
                        child: Text('Restart Helper service'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: _selected.isEmpty
                            ? const Color(0xFFE9EEF3)
                            : _accent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 17,
                            color: _selected.isEmpty ? _muted : Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Device actions',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selected.isEmpty ? _muted : Colors.white,
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            color: Colors.white,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_package != null)
                    _pill('Helper ${_package!.version} selected', _accent),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                _empty(
                  Icons.devices_other_outlined,
                  _devices.isEmpty
                      ? 'Build your device inventory'
                      : 'No matching devices',
                  _devices.isEmpty
                      ? 'Enroll an Agent or import domain computers to get started.'
                      : 'Try a different search or filter.',
                )
              else
                LayoutBuilder(
                  builder: (context, bounds) => SizedBox(
                    height: (MediaQuery.sizeOf(context).height - 490).clamp(
                      260.0,
                      660.0,
                    ),
                    child: _horizontalInventory(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: bounds.maxWidth),
                        child: SingleChildScrollView(
                          primary: false,
                          child: DataTable(
                            headingRowHeight: 46,
                            dataRowMinHeight: 62,
                            dataRowMaxHeight: 62,
                            horizontalMargin: 8,
                            columnSpacing: 24,
                            onSelectAll: (selected) => setState(() {
                              for (final d in rows.where((d) => !d.revoked)) {
                                if (selected == true) {
                                  _selected.add(d.id);
                                } else {
                                  _selected.remove(d.id);
                                }
                              }
                            }),
                            sortColumnIndex: columns.contains(_table.sort)
                                ? columns.indexOf(_table.sort)
                                : null,
                            sortAscending: _table.ascending,
                            columns: [
                              for (final column in columns)
                                DataColumn(
                                  label: Text(column.label.toUpperCase()),
                                  tooltip: 'Sort by ${column.label}',
                                  onSort: (_, ascending) => _setTable(
                                    DeviceTableSettings(
                                      visible: _table.visible,
                                      sort: column,
                                      ascending: ascending,
                                    ),
                                  ),
                                ),
                              const DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final device in rows)
                                DataRow(
                                  key: ValueKey(device.id),
                                  selected: _selected.contains(device.id),
                                  onSelectChanged: device.revoked
                                      ? null
                                      : (selected) => setState(() {
                                          if (selected == true) {
                                            _selected.add(device.id);
                                          } else {
                                            _selected.remove(device.id);
                                          }
                                        }),
                                  cells: [
                                    for (final column in columns)
                                      _inventoryCell(device, column),
                                    _inventoryActions(device),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const Divider(color: _border),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      filtered.isEmpty
                          ? '0 devices'
                          : '${page * _pageSize + 1}–${(page * _pageSize + rows.length)} of ${filtered.length} devices',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                  const Text(
                    'Rows ',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  DropdownButton<int>(
                    value: _pageSize,
                    underline: const SizedBox(),
                    items: [25, 50, 100]
                        .map(
                          (size) => DropdownMenuItem(
                            value: size,
                            child: Text(
                              '$size',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (size) => setState(() {
                      _pageSize = size!;
                      _page = 0;
                    }),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: page == 0
                        ? null
                        : () => setState(() => _page = page - 1),
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Text(
                    '${page + 1} / $pages',
                    style: const TextStyle(fontSize: 11),
                  ),
                  IconButton(
                    onPressed: page >= pages - 1
                        ? null
                        : () => setState(() => _page = page + 1),
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
        ),
      ],
    );
  }

  Widget _activity(Map<String, dynamic> entry) {
    final job = Map<String, dynamic>.from(entry['job'] as Map? ?? {});
    final found = _devices.where((d) => d.id == entry['deviceId']);
    final name = found.isEmpty
        ? entry['deviceId'].toString()
        : found.first.name;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: entry['ok'] == true
              ? const Color(0xFFE7F4EF)
              : const Color(0xFFFFF2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          entry['ok'] == true ? Icons.check : Icons.info_outline,
          color: entry['ok'] == true
              ? const Color(0xFF148368)
              : const Color(0xFFB47A20),
          size: 18,
        ),
      ),
      title: Text(
        '${job['action'] ?? 'install'} · $name',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${entry['message'] ?? ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      trailing: Text(
        _time(entry['finishedUtc']),
        style: const TextStyle(fontSize: 10, color: _muted),
      ),
    );
  }

  Widget _taskPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Tasks & history',
        'Queued work, execution status and the latest 200 completed or cancelled operations.',
        trailing: _button('Refresh', Icons.refresh, _refresh),
      ),
      const SizedBox(height: 24),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle(
              'Active tasks',
              'Agent jobs survive console restarts. Direct domain jobs require this console to remain open.',
            ),
            const SizedBox(height: 15),
            if (!_devices.any((d) => d.hasJob) && _progress.isEmpty)
              _empty(
                Icons.done_all,
                'No active tasks',
                'Select devices to install, update, repair or remove Helper.',
              ),
            for (final device in _devices.where(
              (d) => d.hasJob || _progress.containsKey(d.id),
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${device.transport} · ${_progress[device.id] ?? device.data['job']['action'] ?? 'install'}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pill(
                      _progress[device.id] ??
                          device.data['job']['stage']?.toString() ??
                          device.text('status'),
                      _accent,
                    ),
                    if (device.isAgent)
                      IconButton(
                        tooltip: 'Cancel only if not assigned',
                        onPressed: _busy
                            ? null
                            : () => _run(() => _cancel(device)),
                        icon: const Icon(Icons.cancel_outlined, size: 19),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle(
              'Completed activity',
              'Every reported result includes a device, action, timestamp and diagnostic message.',
            ),
            const SizedBox(height: 14),
            if (_history.isEmpty)
              _empty(
                Icons.receipt_long_outlined,
                'No history yet',
                'Completed tasks will appear here automatically.',
              )
            else
              ..._history.map(_activity),
          ],
        ),
      ),
    ],
  );
  Widget _packagePage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Helper packages',
        'Choose the release you want to deploy. The selected MSI is verified before transfer.',
        trailing: _button(
          'Browse Helper MSI',
          Icons.add,
          _busy ? null : () => _run(_browse),
          primary: true,
        ),
      ),
      const SizedBox(height: 24),
      _card(
        _package == null
            ? _empty(
                Icons.inventory_2_outlined,
                'No Helper package selected',
                'Browse an existing MSI or choose a release from the server library below.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF3F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: _accent,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 17),
                      Expanded(
                        child: _panelTitle(
                          'SubnetDesk Helper ${_package!.version}',
                          File(_package!.path).uri.pathSegments.last,
                        ),
                      ),
                      _pill('Verified MSI metadata', const Color(0xFF148368)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _info('Local package', _package!.path),
                  _info('Product code', _package!.productCode),
                  _info('SHA256', _package!.sha256),
                  const SizedBox(height: 16),
                  _button(
                    'Choose target devices',
                    Icons.devices_outlined,
                    () => _openDevices(),
                    primary: true,
                  ),
                ],
              ),
      ),
      const SizedBox(height: 20),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle(
              'Server package library',
              'Verified releases remain available across console restarts.',
            ),
            const SizedBox(height: 12),
            if (_library.isEmpty)
              _empty(
                Icons.inventory_outlined,
                'No releases in the library',
                'Browse a Helper MSI to register its release on the server.',
              ),
            for (final package in _library)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined, color: _accent),
                title: Text(
                  'Helper ${package['version']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Added ${_time(package['uploadedUtc'])} · SHA256 ${package['sha256'].toString().substring(0, 12)}…',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(() => _selectLibrary(package)),
                    child: const Text('Select release'),
                  ),
                  IconButton(tooltip: 'Delete package', icon: const Icon(Icons.delete_outline),
                    onPressed: _busy ? null : () => _run(() => _deleteLibrary(package))),
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _card(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Release handling',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
            'Install / update uses the exact selected MSI. Repair and removal target the Helper already installed on each device. Agent and management components remain independent of Helper. Helper Build121+ re-applies Receiver-only on every install, repair or update. Stored unlock verifiers and unattended credentials are preserved.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _agentUpdatesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Agent updates',
        'Update the installed Agent without changing its registration or Helper installation.',
      ),
      const SizedBox(height: 20),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle(
              'Agent package library',
              'Choose the exact Agent setup EXE to deploy.',
            ),
            const SizedBox(height: 14),
            const Text(
              'Agents need version 1.4.0 or later installed once to support dashboard updates. Older versions require that initial upgrade on the target. Select Agent devices in Devices, return here, then queue the update. Offline devices wait until they reconnect.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.7),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _button(
                  'Browse Agent EXE',
                  Icons.file_open_outlined,
                  _busy || !_connected
                      ? null
                      : () => _run(() => _uploadAgent(false)),
                ),
                _button(
                  'Use bundled Agent',
                  Icons.inventory_2_outlined,
                  _busy || !_connected
                      ? null
                      : () => _run(() => _uploadAgent(true)),
                ),
                _button(
                  'Select devices',
                  Icons.devices,
                  () => setState(() => _section = 1),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_agentPackage != null)
              _info('Selected Agent', _agentPackage!['version'].toString()),
            _info(
              'Selected devices',
              '${_devices.where((d) => d.isAgent && !d.revoked && _selected.contains(d.id)).length} Agent devices',
            ),
            _button(
              'Queue Agent update',
              Icons.system_update_alt,
              _busy || !_connected || _agentPackage == null || _selected.isEmpty
                  ? null
                  : () => _run(_queueAgentUpdate),
              primary: true,
            ),
            const SizedBox(height: 18),
            if (_agentPackages.isEmpty)
              const Text(
                'No Agent packages uploaded yet.',
                style: TextStyle(color: _muted),
              ),
            for (final package in _agentPackages)
              ListTile(
                leading: const Icon(Icons.system_update_alt),
                title: Text('SubnetDesk Agent ${package['version']}'),
                subtitle: Text(
                  '${package['uploadedUtc'] ?? ''}\nSHA256: ${package['sha256']}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _agentPackage = package),
                  child: Text(
                    _agentPackage?['sha256'] == package['sha256']
                        ? 'Selected'
                        : 'Select',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'The Agent downloads and verifies the package, restarts its own service, and reports the running version. A startup failure restores the previous runtime. Follow results in Tasks & history.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.7),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _uploadAgent(bool bundled) async {
    String? path;
    if (bundled) {
      path =
          '${File(Platform.resolvedExecutable).parent.path}\\deployment\\SubnetDeskAgent.exe';
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['exe'],
      );
      path = result?.files.single.path;
    }
    if (path == null) return;
    final file = File(path);
    if (!await file.exists())
      throw const FormatException('Agent setup EXE was not found.');
    if (await file.length() > 64 * 1024 * 1024)
      throw const FormatException('Agent setup must be no larger than 64 MB.');
    final client = await _connection();
    final package = await client.call('agent-package', file: file);
    if (mounted) setState(() => _agentPackage = package);
    await _refresh();
    _notice('Agent ${package['version']} uploaded and selected.');
  }

  Future<void> _queueAgentUpdate() async {
    final targets = _devices
        .where((d) => d.isAgent && !d.revoked && _selected.contains(d.id))
        .toList();
    if (_agentPackage == null) {
      setState(() => _section = 6);
      _notice('Choose an Agent setup EXE first.');
      return;
    }
    if (targets.isEmpty) {
      _notice('Select Agent devices in Devices first.');
      return;
    }
    if (!await _confirm(
      'Update Agent on ${targets.length} devices?',
      'Target version: ${_agentPackage!['version']}. The Agent service briefly disconnects during replacement. Registration and Helper remain installed. Older Agents without update support and devices already on this version will be skipped.',
    ))
      return;
    final client = await _connection();
    final reply = await client.call(
      'jobs',
      body: {
        'action': 'agent-update',
        'sha256': _agentPackage!['sha256'],
        'deviceIds': targets.map((d) => d.id).toList(),
      },
    );
    final results = (reply['results'] as List).cast<Map>();
    final queued = results.where((r) => r['queued'] == true).length;
    final skipped = results.where((r) => r['queued'] != true).toList();
    await _refresh();
    if (mounted) setState(() => _section = 2);
    _notice(
      '$queued Agent updates queued; ${skipped.length} skipped.${skipped.isEmpty ? '' : ' ${skipped.map((r) => r['reason'] ?? 'Device busy or unavailable.').toSet().join(' ')}'}',
    );
  }

  Widget _requestsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Agent requests',
        'Computers waiting for your approval. Pending devices cannot receive management tasks.',
      ),
      const SizedBox(height: 20),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_requests.length} pending requests',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Check the computer name and source address before approving. Names are reported by the requesting computer. Compare its Diagnostics verification fingerprint when needed. Requests expire after seven days.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _button(
                  'Select all requests',
                  Icons.select_all,
                  _busy
                      ? null
                      : () => setState(
                          () => _requestSelection.addAll(
                            _requests.map((r) => r['id'].toString()),
                          ),
                        ),
                ),
                _button(
                  'Clear selection',
                  Icons.deselect,
                  _busy ? null : () => setState(_requestSelection.clear),
                ),
                _button(
                  'Approve selected (${_requestSelection.length})',
                  Icons.check_circle_outline,
                  _busy || !_connected || _requestSelection.isEmpty
                      ? null
                      : () => _run(() => _decideRequests(true)),
                  primary: true,
                ),
                _button(
                  'Reject selected',
                  Icons.block,
                  _busy || !_connected || _requestSelection.isEmpty
                      ? null
                      : () => _run(() => _decideRequests(false)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_requests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pending requests. Install the Agent and choose Install & connect on a target computer.',
                ),
              ),
            if (_requests.isNotEmpty)
              SizedBox(
                height: 440,
                child: ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final id = request['id'].toString();
                    return CheckboxListTile(
                      value: _requestSelection.contains(id),
                      onChanged: _busy
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _requestSelection.add(id);
                              } else {
                                _requestSelection.remove(id);
                              }
                            }),
                      title: Text(
                        request['machine']?.toString() ?? 'Unknown computer',
                      ),
                      subtitle: Text(
                        '${request['address'] ?? ''}  •  ${request['domain'] ?? ''}\nVerification: ${request['verification'] ?? ''}  •  Requested: ${request['createdUtc'] ?? ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      isThreeLine: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Future<void> _decideRequests(bool approve) async {
    final ids = _requestSelection.toList();
    final accepted = await _modal<bool>(
      AlertDialog(
        title: Text(
          '${approve ? 'Approve' : 'Reject'} ${ids.length} computers?',
        ),
        content: Text(
          approve
              ? 'Approved computers can receive Helper management tasks. Verify that every selected computer belongs to your organization.'
              : 'These requests will be rejected and will receive no management access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final client = await _connection();
    int done = 0;
    try {
      for (final id in ids) {
        await client.call(
          'requests/${approve ? 'approve' : 'reject'}',
          body: {'deviceId': id},
        );
        done++;
        if (mounted)
          setState(
            () => _operationLabel = '$done of ${ids.length} requests processed',
          );
      }
    } finally {
      await _refresh();
    }
    _notice(
      '$done requests ${approve ? 'approved' : 'rejected'}. Approved Agents will connect automatically.',
    );
  }

  Widget _settingsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Server & enrollment',
        'Configure the management service and connect devices to this workspace.',
      ),
      const SizedBox(height: 24),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _panelTitle(
                    'Management server',
                    'Persistent Windows service on this Deploy computer',
                  ),
                ),
                _pill(
                  _connected ? 'Connected' : 'Not connected',
                  _connected
                      ? const Color(0xFF148368)
                      : const Color(0xFFB47A20),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _info('Computer', Platform.localHostname),
            _info(
              'Endpoint',
              _client?.config['server']?.toString() ?? 'Not configured',
            ),
            _info(
              'Certificate SHA256',
              _client?.config['certificateSha256']?.toString() ??
                  'Not available',
            ),
            const SizedBox(height: 15),
            _button(
              'Configure / repair server',
              Icons.settings_ethernet,
              _busy ? null : () => _run(_setupServer),
              primary: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle(
              'Agent installation & registration',
              'Install a managed background service on devices that need an outbound connection.',
            ),
            const SizedBox(height: 16),
            const Text(
              'The Agent setup EXE installs its Windows service, stores a unique device identity and connects to this server over HTTPS 443. The service starts with Windows and stays active when its settings window is closed.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
            ),
            const SizedBox(height: 18),
            _button(
              'Export reusable Agent setup',
              Icons.person_add_alt_1,
              _busy || !_connected ? null : () => _run(_enroll),
              primary: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle(
              'Domain management',
              'A direct management path for domain computers without Agent.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Import computers from Active Directory or enter their DNS names. Test WinRM HTTPS and domain administrator access before running tasks. Credentials are requested for each operation and are never saved in the inventory.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
            ),
            const SizedBox(height: 18),
            _button(
              'Add domain computers',
              Icons.domain_add_outlined,
              _busy || !_connected ? null : () => _run(_importDomain),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
  Future<T?> _modal<T>(Widget dialog) async {
    final route = DialogRoute<T>(
      context: context,
      barrierDismissible: !_busy,
      builder: (_) => Theme(
        data: ThemeData(
          useMaterial3: true,
          fontFamily: 'Segoe UI',
          colorScheme: ColorScheme.fromSeed(seedColor: _accent),
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
          ),
        ),
        child: dialog,
      ),
    );
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    return result;
  }

  Future<bool> _confirm(String title, String message) async =>
      await _modal<bool>(
        AlertDialog(
          title: Text(title),
          content: SizedBox(width: 420, child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ==
      true;
  void _addDevices() async {
    final method = await _modal<String>(
      AlertDialog(
        title: const Text('Add devices to your inventory'),
        content: SizedBox(
          width: 490,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.install_desktop_outlined,
                  color: _accent,
                ),
                title: const Text('Install Agent on devices'),
                subtitle: const Text(
                  'Use one reusable setup for all devices, then approve their requests. Outbound HTTPS; no WinRM needed.',
                ),
                onTap: () => Navigator.pop(context, 'agent'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.domain_outlined,
                  color: Color(0xFF5275C8),
                ),
                title: const Text('Add domain / WinRM computers'),
                subtitle: const Text(
                  'Discover from Active Directory or import device names. No Agent installation.',
                ),
                onTap: () => Navigator.pop(context, 'domain'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (method != null) await _run(method == 'agent' ? _enroll : _importDomain);
  }

  Future<void> _importDomain() async {
    final targets = TextEditingController();
    final group = TextEditingController();
    String? error;
    bool discovering = false;
    try {
      final accepted = await _modal<bool>(
        StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Add domain computers'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import does not install software or imply management readiness. Connection and administrator access must be verified before tasks.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: discovering
                              ? null
                              : () async {
                                  update(() {
                                    discovering = true;
                                    error = null;
                                  });
                                  try {
                                    final devices =
                                        await DomainDiscovery.discover();
                                    if (context.mounted)
                                      update(
                                        () => targets.text = devices.join('\n'),
                                      );
                                  } catch (e) {
                                    if (context.mounted)
                                      update(
                                        () => error = e is FormatException
                                            ? e.message
                                            : 'Directory discovery could not finish. Import a device list instead.',
                                      );
                                  } finally {
                                    if (context.mounted)
                                      update(() => discovering = false);
                                  }
                                },
                          icon: const Icon(Icons.domain_add, size: 17),
                          label: const Text('Discover Active Directory'),
                        ),
                        OutlinedButton.icon(
                          onPressed: discovering
                              ? null
                              : () async {
                                  final pick = await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['txt', 'csv'],
                                  );
                                  final path = pick?.files.single.path;
                                  if (path != null) {
                                    final content = await File(
                                      path,
                                    ).readAsString();
                                    if (context.mounted)
                                      update(() => targets.text = content);
                                  }
                                },
                          icon: const Icon(Icons.upload_file, size: 17),
                          label: const Text('Import names'),
                        ),
                      ],
                    ),
                    if (discovering)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: targets,
                      minLines: 6,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'DNS names / IP addresses',
                        hintText:
                            'PC-001.company.local\nPC-002.company.local\n192.168.50.0/24',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: group,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Group (optional)',
                        hintText: 'Head office / Finance / Lab',
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: discovering
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: discovering
                    ? null
                    : () {
                        try {
                          final parsed = parseDeploymentTargets(targets.text);
                          if (parsed.isEmpty) {
                            update(() => error = 'Add at least one device.');
                            return;
                          }
                          Navigator.pop(context, true);
                        } on FormatException catch (e) {
                          update(() => error = e.message);
                        }
                      },
                child: const Text('Add to inventory'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      final result = await (await _connection()).call(
        'domain/import',
        body: {
          'targets': parseDeploymentTargets(targets.text),
          'group': group.text.trim(),
        },
      );
      await _refresh();
      if (mounted) {
        _openDevices(method: 'domain');
        _notice(
          '${result['added']} domain computers added. Select them to verify management access.',
        );
      }
    } finally {
      targets.dispose();
      group.dispose();
    }
  }

  Future<void> _browse() async {
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['msi'],
    );
    final path = pick?.files.single.path;
    if (path == null) return;
    final package = await HelperMsiPackage.inspect(path);
    if (mounted) {
      setState(() => _package = package);
      _notice('Helper ${package.version} selected and MSI metadata verified.');
    }
    if (_connected) {
      final uploaded = await (await _connection()).call(
        'package',
        file: File(path),
      );
      if (uploaded['sha256'] != package.sha256)
        throw const FormatException('Package changed while uploading.');
      await _refresh();
    }
  }

  Future<void> _selectLibrary(Map<String, dynamic> release) async {
    final sha = release['sha256'].toString();
    if (!RegExp(r'^[A-F0-9]{64}$').hasMatch(sha))
      throw const FormatException('Invalid package identity.');
    final root = Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    final package = await HelperMsiPackage.inspect(
      '$root\\SubnetDesk Deployment\\Management\\packages\\$sha.msi',
    );
    if (package.sha256 != sha)
      throw const FormatException('Package integrity could not be verified.');
    if (mounted) setState(() => _package = package);
  }

  String? _validateHelperPassword(String password, String confirmation) {
    if (password.isEmpty || utf8.encode(password).length > 180)
      return 'Enter a password of 1–180 UTF-8 bytes.';
    if (RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(password))
      return 'Passwords cannot contain control characters.';
    if (password != confirmation)
      return 'The new password and confirmation do not match.';
    return null;
  }

  Future<void> _configureHelper() async {
    final targets = _devices
        .where((d) => _selected.contains(d.id) && d.isAgent && !d.revoked)
        .toList();
    if (targets.isEmpty) {
      _notice(
        'Select Agent devices for Helper security settings. Domain-only records are excluded.',
      );
      return;
    }
    final current = TextEditingController(),
        password = TextEditingController(),
        confirm = TextEditingController();
    String operation = 'unattended-password';
    String? error;
    const operations = {
      'unattended-password': 'Change unattended access password',
      'receiver-lock': 'Lock all accounts as receiver-only',
      'receiver-unlock': 'Unlock all accounts to send-and-receive',
      'receiver-password': 'Change device receiver unlock password',
    };
    try {
      final accepted = await _modal<bool>(
        StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Helper security settings'),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${targets.length} Agent devices selected.'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: operation,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: operations.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => update(() {
                        operation = value!;
                        error = null;
                        current.clear();
                        password.clear();
                        confirm.clear();
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      operation == 'unattended-password'
                          ? 'This changes the unattended access password and restarts Helper service to reload it. Active Helper sessions may disconnect. Agent stays connected. Receiver policy and its unlock password remain unchanged. Requires Agent 1.5.0+.'
                          : 'Applies to this device and every Windows account, including future users. Requires Helper 1.4.5+ and Agent 1.6.0+. Local Helper settings cannot override a device policy. New outgoing connections follow it immediately; existing sessions are not forcibly terminated. Reopen Helper to refresh its layout.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.6,
                      ),
                    ),
                    if (operation == 'receiver-lock')
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'The first device-wide lock replaces per-user receiver policy with the password you choose. An existing locked device policy requires its current password to rotate the unlock password.',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ),
                    if (operation == 'receiver-unlock' ||
                        operation == 'receiver-password') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: current,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Current receiver unlock password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The current receiver password is verified before changing the policy. This is not the unattended access password.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                    if (operation != 'receiver-unlock') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: password,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: operation == 'unattended-password'
                              ? 'New unattended password'
                              : 'New receiver unlock password',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirm,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Passwords travel over HTTPS, are protected in the server queue, and are excluded from inventory and task history. Sensitive tasks expire after 24 hours.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _muted,
                        height: 1.6,
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (operation != 'receiver-unlock') {
                    final validation = _validateHelperPassword(
                      password.text,
                      confirm.text,
                    );
                    if (validation != null) {
                      update(() => error = validation);
                      return;
                    }
                  }
                  if (operation == 'receiver-unlock' ||
                      operation == 'receiver-password') {
                    final validation = _validateHelperPassword(
                      current.text,
                      current.text,
                    );
                    if (validation != null) {
                      update(
                        () => error =
                            'Enter the current receiver unlock password.',
                      );
                      return;
                    }
                  }
                  Navigator.pop(context, true);
                },
                child: Text(
                  operation == 'unattended-password'
                      ? 'Queue password change'
                      : 'Queue receiver policy',
                ),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      final client = await _connection();
      final reply = await client.call(
        'jobs',
        body: {
          'action': 'configure-helper',
          'deviceIds': targets.map((d) => d.id).toList(),
          'settings': {
            'operation': operation,
            if (operation == 'receiver-unlock' ||
                operation == 'receiver-password')
              'currentPassword': current.text,
            if (operation != 'receiver-unlock') 'newPassword': password.text,
          },
        },
      );
      final rows = (reply['results'] as List).cast<Map>();
      final queued = rows.where((r) => r['queued'] == true).length;
      await _refresh();
      if (mounted) setState(() => _section = 2);
      _notice(
        '$queued Helper security tasks queued; ${rows.length - queued} skipped. ${rows.where((r) => r['queued'] != true).map((r) => r['reason'] ?? 'Device busy or unavailable.').toSet().join(' ')}',
      );
    } finally {
      current.clear();
      current.dispose();
      password.clear();
      password.dispose();
      confirm.clear();
      confirm.dispose();
    }
  }

  Future<void> _execute(String action) async {
    if (action == 'helper-settings') {
      await _configureHelper();
      return;
    }
    if (action == 'agent-update') {
      await _queueAgentUpdate();
      return;
    }
    var targets = _devices
        .where((d) => _selected.contains(d.id) && !d.revoked)
        .toList();
    if (action == 'test') targets = targets.where((d) => !d.isAgent).toList();
    if (targets.isEmpty) {
      _notice(
        action == 'test'
            ? 'Select domain devices to test WinRM. Agent connectivity is reported by its heartbeat.'
            : 'Select devices first.',
      );
      return;
    }
    if (action == 'install' && _package == null) {
      await _browse();
      if (_package == null) return;
    }
    final agents = targets.where((d) => d.isAgent).toList();
    final domains = targets.where((d) => !d.isAgent).toList();
    final username = TextEditingController();
    final password = TextEditingController();
    final concurrency = TextEditingController(text: '20');
    final unattended = TextEditingController();
    final unattendedConfirm = TextEditingController();
    bool configureUnattended = false;
    bool prepare = false;
    String? validation;
    try {
      final approved = await _modal<bool>(
        StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(
              action == 'test'
                  ? 'Verify domain connections'
                  : '${action[0].toUpperCase()}${action.substring(1)} Helper',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${targets.length} devices selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (agents.isNotEmpty)
                      Text(
                        '${agents.length} Agent devices · tasks remain queued while offline.',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    if (domains.isNotEmpty)
                      Text(
                        '${domains.length} domain devices · direct HTTPS management.',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    if (action == 'install')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Selected Helper version: ${_package!.version}',
                        ),
                      ),
                    if (action == 'install') ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: configureUnattended,
                        onChanged: (value) =>
                            update(() => configureUnattended = value ?? false),
                        title: const Text('Set unattended access password'),
                        subtitle: const Text(
                          'This is separate from the Receiver-only unlock password. Agent 1.5.0+ is required for Agent devices. Unchecked preserves the MSI default/existing password.',
                        ),
                      ),
                      if (configureUnattended) ...[
                        TextField(
                          controller: unattended,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Unattended access password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: unattendedConfirm,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Confirm unattended password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sent over HTTPS. Agent queue credentials are protected on the server, excluded from task history, and expire after 24 hours. Helper service is restarted to load the new password; active Helper sessions may disconnect.',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ],
                    if (action == 'uninstall' || action == 'stop')
                      const Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: Text(
                          'This interrupts Helper access on the selected devices. Agent remains installed and connected.',
                          style: TextStyle(
                            color: Color(0xFFAD5C1B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (domains.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const Divider(),
                      const Text(
                        'Domain administrator credentials',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'DOMAIN\\user or user@domain',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        controller: password,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Password · used for this operation only',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        controller: concurrency,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Simultaneous domain operations',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (action == 'test')
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: prepare,
                          onChanged: (value) =>
                              update(() => prepare = value ?? false),
                          title: const Text(
                            'Prepare HTTPS if unavailable',
                            style: TextStyle(fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Requires existing Kerberos remoting and a DNS hostname.',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Keep this console open until domain operations finish. Credentials are never stored on the server.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                    if (validation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          validation!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (configureUnattended) {
                    final error = _validateHelperPassword(
                      unattended.text,
                      unattendedConfirm.text,
                    );
                    if (error != null) {
                      update(() => validation = error);
                      return;
                    }
                  }
                  if (domains.isNotEmpty &&
                      (username.text.trim().isEmpty ||
                          password.text.isEmpty ||
                          (int.tryParse(concurrency.text) ?? 0) < 1)) {
                    update(
                      () => validation =
                          'Enter credentials and a positive concurrency count.',
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: Text(
                  action == 'test' ? 'Test connections' : 'Confirm $action',
                ),
              ),
            ],
          ),
        ),
      );
      if (approved != true) return;
      final client = await _connection();
      HelperMsiPackage? package;
      if (action == 'install') {
        package = await HelperMsiPackage.inspect(_package!.path);
        if (package.sha256 != _package!.sha256)
          throw const FormatException(
            'The selected package changed. Browse it again.',
          );
      }
      if (agents.isNotEmpty) {
        if (package != null) {
          final upload = await client.call('package', file: File(package.path));
          if (upload['sha256'] != package.sha256)
            throw const FormatException(
              'Uploaded package differs from the selected MSI.',
            );
        }
        final result = await client.call(
          'jobs',
          body: {
            'action': action,
            'sha256': package?.sha256 ?? '',
            'deviceIds': agents.map((d) => d.id).toList(),
            if (configureUnattended)
              'settings': {
                'operation': 'unattended-password',
                'newPassword': unattended.text,
              },
          },
        );
        final rows = result['results'] as List;
        final queued = rows.where((r) => r['queued'] == true).length;
        _notice(
          '$queued Agent tasks queued; ${rows.length - queued} skipped. ${rows.whereType<Map>().where((r) => r['queued'] != true).map((r) => r['reason'] ?? 'Device busy or unavailable.').toSet().join(' ')}',
        );
      }
      if (domains.isNotEmpty) {
        final byAddress = {for (final d in domains) d.address: d};
        final saves = <Future<void>>[];
        int saveFailures = 0;
        if (mounted)
          setState(() {
            for (final d in domains) {
              _progress[d.id] = 'Waiting';
            }
          });
        final requests = domains
            .map(
              (d) => RemoteHelperDeploymentRequest(
                target: d.address,
                username: username.text.trim(),
                administratorPassword: password.text,
                msiPath: package?.path ?? '',
                package: package,
                accountType: DeploymentAccountType.qualified,
                testOnly: action == 'test',
                prepareHttps: prepare,
                action: action == 'test' ? 'install' : action,
                configureUnattended: configureUnattended,
                unattendedPassword: configureUnattended ? unattended.text : '',
              ),
            )
            .toList();
        int completed = 0;
        if (mounted)
          setState(() {
            _canStopPending = true;
            _operationLabel = 'Domain tasks: 0 of ${domains.length} completed';
          });
        await BulkHelperDeployment().run(
          requests,
          PowerShellRemotingHelperDeployer(),
          concurrency: int.parse(concurrency.text),
          cancelled: () => _stopPending,
          onResult: (address, result) {
            final device = byAddress[address]!;
            completed++;
            if (mounted)
              setState(
                () => _operationLabel =
                    'Domain tasks: $completed of ${domains.length} completed',
              );
            if (mounted)
              setState(
                () => _progress[device.id] = result.succeeded
                    ? 'Succeeded'
                    : 'Failed',
              );
            saves.add(
              client
                  .call(
                    'domain/result',
                    body: {
                      'deviceId': device.id,
                      'action': action,
                      'ok': result.succeeded,
                      'message': result.message,
                      'inventory': result.inventory,
                      'version': package?.version ?? '',
                    },
                  )
                  .then<void>((_) {})
                  .catchError((Object _) {
                    saveFailures++;
                  }),
            );
          },
        );
        await Future.wait(saves);
        if (completed != domains.length)
          _notice(
            '${domains.length - completed} domain tasks were not started. Running operations were allowed to finish.',
          );
        if (mounted)
          setState(() {
            for (final d in domains) {
              _progress.remove(d.id);
            }
          });
        if (saveFailures != 0)
          _notice(
            '$saveFailures results could not be saved to the server. Verify those devices before retrying.',
          );
      }
      await _refresh();
      if (mounted) setState(() => _section = 2);
    } finally {
      username.dispose();
      password.clear();
      password.dispose();
      unattended.clear();
      unattended.dispose();
      unattendedConfirm.clear();
      unattendedConfirm.dispose();
      concurrency.dispose();
    }
  }

  Future<void> _deleteLibrary(Map<String, dynamic> package) async {
    if (!await _confirm('Delete Helper package?',
        'Delete Helper ${package['version']} from the server library? This does not uninstall Helper from devices. Packages needed by queued or running tasks cannot be deleted.')) return;
    await (await _connection()).call('packages/remove', body: {'sha256': package['sha256']});
    if (_package?.sha256 == package['sha256']) _package = null;
    await _refresh();
  }

  Future<void> _cancel(ManagedDevice device) async {
    await (await _connection()).call('cancel', body: {'deviceId': device.id});
    await _refresh();
  }

  void _deviceMenu(ManagedDevice device, String action) async {
    if (action == 'details') {
      _details(device);
      return;
    }
    await _run(() async {
      if (action == 'edit') {
        await _edit(device);
        return;
      }
      if (action == 'cancel') {
        await _cancel(device);
        return;
      }
      if (!await _confirm(
        action == 'revoke'
            ? 'Revoke Agent access?'
            : 'Delete device?',
        action == 'revoke'
            ? '${device.name} will no longer be allowed to communicate with this server. Running MSI operations cannot be stopped by revocation.'
            : 'Delete ${device.name} from the inventory? ${device.isAgent && !device.revoked ? "Its Agent access will also be revoked so it cannot reconnect using this registration. " : ""}This does not uninstall Helper or Agent. Finish or cancel its active task first.',
      ))
        return;
      if (action == 'remove' && device.isAgent && !device.revoked) {
        await (await _connection()).call('revoke', body: {'deviceId': device.id});
      }
      await (await _connection()).call(
        action == 'revoke' ? 'revoke' : 'device/remove',
        body: {'deviceId': device.id},
      );
      await _refresh();
    });
  }

  Future<void> _edit(ManagedDevice device) async {
    final name = TextEditingController(text: device.name);
    final group = TextEditingController(text: device.text('group'));
    try {
      final accepted = await _modal<bool>(
        AlertDialog(
          title: const Text('Edit device'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: group,
                  decoration: const InputDecoration(labelText: 'Group'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (accepted == true) {
        await (await _connection()).call(
          'device/edit',
          body: {
            'deviceId': device.id,
            'name': name.text.trim(),
            'group': group.text.trim(),
          },
        );
        await _refresh();
      }
    } finally {
      name.dispose();
      group.dispose();
    }
  }

  void _details(ManagedDevice device) {
    _modal<void>(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.desktop_windows_outlined, color: _accent),
            const SizedBox(width: 12),
            Expanded(child: Text(device.name)),
            _pill(
              device.connection,
              device.online ? const Color(0xFF148368) : _muted,
            ),
          ],
        ),
        content: SizedBox(
          width: 590,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _info('Management', device.transport),
                _info(
                  'Computer name',
                  device.text('machine').isEmpty
                      ? 'Not reported'
                      : device.text('machine'),
                ),
                _info('Address / hostname', device.address),
                _info('Device ID', device.id),
                _info('Group', device.group),
                _info(
                  'Domain reported',
                  device.text('domain').isEmpty
                      ? 'Not reported'
                      : device.text('domain'),
                ),
                _info(
                  'Operating system',
                  device.text('operatingSystem').isEmpty
                      ? 'Not reported'
                      : device.text('operatingSystem'),
                ),
                _info(
                  'Architecture',
                  device.text('architecture').isEmpty
                      ? 'Not reported'
                      : device.text('architecture'),
                ),
                _info(
                  'Domain joined',
                  device.text('domainJoined').isEmpty
                      ? 'Not verified'
                      : device.text('domainJoined'),
                ),
                _info('Helper version', device.version),
                _info(
                  'Receiver policy scope',
                  device.text('receiverScope').isEmpty
                      ? 'Not reported'
                      : device.text('receiverScope'),
                ),
                _info(
                  'Device receiver mode',
                  device.text('receiverOnly').isEmpty
                      ? 'Not reported'
                      : device.text('receiverOnly').toLowerCase() == 'true'
                      ? 'Receiver-only'
                      : 'Send-and-receive',
                ),
                _info(
                  'Helper service',
                  device.text('helperService').isEmpty
                      ? 'Not reported'
                      : device.text('helperService'),
                ),
                if (device.isAgent)
                  _info(
                    'Agent version',
                    device.text('agentVersion').isEmpty
                        ? 'Not reported'
                        : device.text('agentVersion'),
                  ),
                _info(
                  'Last seen / verified',
                  device.text(device.isAgent ? 'lastSeenUtc' : 'checkedUtc'),
                ),
                const Divider(),
                _info('Last task status', device.text('status')),
                _info(
                  'Diagnostic message',
                  device.text('message').isEmpty
                      ? 'No diagnostic message.'
                      : device.text('message'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDevices() async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export filtered inventory',
      fileName: 'SubnetDesk-devices.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    String csv(Object? value) {
      var text = value?.toString() ?? '';
      if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final columns = _table.columns;
    final rows = <List<Object?>>[
      columns.map((c) => c.label).toList(),
      ..._filtered.map((d) => columns.map((c) => c.value(d)).toList()),
    ];
    await File(path).writeAsString(
      '\uFEFF${rows.map((row) => row.map(csv).join(',')).join('\r\n')}',
    );
    _notice('${_filtered.length} inventory records exported.');
  }

  Future<void> _setupServer() async {
    final host = TextEditingController(
      text: _client == null
          ? Platform.localHostname
          : Uri.parse(_client!.config['server'] as String).host,
    );
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    if (!mounted) return;
    String? address;
    String? error;
    try {
      final confirmed = await _modal<bool>(
        StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Configure management server'),
            content: SizedBox(
              width: 530,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Run this console as administrator. Select the network interface used by your managed devices. Existing registrations and certificates are preserved when repairing setup.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: host,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Stable server DNS name or IPv4 address',
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: address,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'LAN interface for Agent connections',
                    ),
                    items: [
                      for (final interface in interfaces)
                        for (final ip in interface.addresses)
                          DropdownMenuItem(
                            value: ip.address,
                            child: Text(
                              '${ip.address} · ${interface.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (value) => update(() => address = value),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Creates / repairs HTTPS 443 on IPv4 and IPv6. The firewall allows local subnets on this interface, including Public profiles. Unrelated HTTPS bindings are never overwritten.',
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.6),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (address == null ||
                      !RegExp(
                        r'^[a-zA-Z0-9][a-zA-Z0-9.\-]{0,252}$',
                      ).hasMatch(host.text.trim())) {
                    update(
                      () => error =
                          'Enter a valid server name and select an interface.',
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Apply server configuration'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      final script =
          '${File(Platform.resolvedExecutable).parent.path}\\deployment\\Initialize-Management.ps1';
      final result = await Process.run(
        '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script,
          '-ServerName',
          host.text.trim(),
          '-LanAddress',
          address!,
        ],
      );
      if (result.exitCode != 0)
        throw const FormatException(
          'Server configuration failed. Check administrator access, the selected interface and existing HTTPS certificate bindings.',
        );
      _client?.close();
      _client = null;
      for (var attempt = 0; attempt < 15; attempt++) {
        await _refresh();
        if (_connected) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      _notice(
        _connected
            ? 'Management service is connected. Your existing registrations were preserved.'
            : 'Configuration finished, but the service is not reachable. Review the management service log.',
      );
    } finally {
      host.dispose();
    }
  }

  Future<void> _enroll() async {
    if (!_connected) {
      setState(() => _section = 4);
      _notice(
        'Connect the management server before exporting an Agent installer.',
      );
      return;
    }
    if (!await _confirm(
      'Export reusable Agent setup?',
      'Use the same installer on all your computers. It contains this server address and public certificate identity, without registration secrets or expiry. Each computer requests approval in Agent requests.',
    ))
      return;
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Export reusable Agent setup',
    );
    if (folder == null) return;
    final source = File(
      '${File(Platform.resolvedExecutable).parent.path}\\deployment\\SubnetDeskAgent.exe',
    );
    if (!await source.exists())
      throw const FormatException(
        'The bundled Agent installer is missing. Repair this Deploy installation.',
      );
    final client = await _connection();
    final registration = {
      'server': client.config['server'],
      'certificateSha256': client.config['certificateSha256'],
      'approvalRequired': 'true',
    };
    final bytes = utf8.encode(jsonEncode(registration));
    final length = ByteData(4)..setUint32(0, bytes.length, Endian.little);
    final output = await Directory(
      '$folder\\SubnetDesk-Agent-Setup-${DateTime.now().millisecondsSinceEpoch}',
    ).create();
    final destination = File('${output.path}\\SubnetDeskAgent-Setup.exe');
    final stream = destination.openWrite();
    stream.add(await source.readAsBytes());
    stream.add(bytes);
    stream.add(length.buffer.asUint8List());
    stream.add(utf8.encode('SUBNETDESK_ENROLLMENT_V1'));
    await stream.close();
    _notice(
      'Reusable setup exported to ${destination.path}. Install on your computers, then approve their Agent requests.',
    );
  }
}
