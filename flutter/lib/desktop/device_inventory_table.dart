import 'dart:convert';
import 'dart:io';
import 'management_models.dart';

enum InventoryColumn {
  device('Device', 200),
  computerName('Computer name', 170),
  address('IP / hostname', 160),
  connection('Connection', 110),
  management('Management', 115),
  helperVersion('Helper version', 115),
  helperService('Helper service', 110),
  agentVersion('Agent version', 105),
  operatingSystem('Windows version', 280),
  receiverMode('Device receiver mode', 160),
  receiverScope('Receiver policy scope', 150),
  architecture('Architecture', 95),
  domain('Domain / workgroup', 170),
  domainJoined('Domain joined', 105),
  group('Group', 140),
  lastSeen('Last seen / test', 140),
  status('Last task status', 190),
  currentTask('Current task', 190),
  agentUpdateSupport('Agent update support', 160),
  deviceId('Device ID', 280),
  message('Diagnostic message', 300);

  const InventoryColumn(this.label, this.width);
  final String label;
  final double width;

  String value(ManagedDevice d) => switch (this) {
    device => d.name,
    computerName => d.text('machine'),
    address => d.address,
    connection => d.connection,
    management => d.transport,
    helperVersion => d.text('helperVersion'),
    helperService => d.text('helperService'),
    agentVersion => d.text('agentVersion'),
    operatingSystem => d.text('operatingSystem'),
    receiverMode => switch (d.text('receiverOnly').toLowerCase()) {
      'true' => 'Receiver-only',
      'false' => 'Send-and-receive',
      _ => '',
    },
    receiverScope => d.text('receiverScope'),
    architecture => d.text('architecture'),
    domain => d.text('domain'),
    domainJoined => switch (d.text('domainJoined').toLowerCase()) {
      'true' => 'Yes',
      'false' => 'No',
      _ => '',
    },
    group => d.group,
    lastSeen => d.text(d.isAgent ? 'lastSeenUtc' : 'checkedUtc'),
    status => d.text('status'),
    currentTask =>
      d.hasJob
          ? '${d.data['job']['action'] ?? ''} · ${d.data['job']['stage'] ?? d.data['job']['state'] ?? ''}'
          : '',
    agentUpdateSupport =>
      d.isAgent
          ? (d.text('agentUpdateProtocol') == '1'
                ? 'Supported'
                : 'Not reported')
          : 'Not applicable',
    deviceId => d.id,
    message => d.text('message'),
  };
}

class DeviceTableSettings {
  DeviceTableSettings({
    Set<InventoryColumn>? visible,
    this.sort = InventoryColumn.device,
    this.ascending = true,
  }) : visible = Set.unmodifiable(visible ?? defaults);
  static const defaults = {
    InventoryColumn.device,
    InventoryColumn.connection,
    InventoryColumn.management,
    InventoryColumn.helperVersion,
    InventoryColumn.agentVersion,
    InventoryColumn.operatingSystem,
    InventoryColumn.receiverMode,
    InventoryColumn.group,
    InventoryColumn.lastSeen,
  };
  final Set<InventoryColumn> visible;
  final InventoryColumn sort;
  final bool ascending;
  List<InventoryColumn> get columns =>
      InventoryColumn.values.where(visible.contains).toList();
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'visible': columns.map((c) => c.name).toList(),
    'sort': sort.name,
    'ascending': ascending,
  };
  factory DeviceTableSettings.fromJson(Map<String, dynamic> json) {
    final ids = (json['visible'] is List ? json['visible'] as List : [])
        .toSet();
    final visible = InventoryColumn.values
        .where((c) => ids.contains(c.name))
        .toSet();
    if (visible.isEmpty) return DeviceTableSettings();
    final sort =
        visible.where((c) => c.name == json['sort']).firstOrNull ??
        InventoryColumn.values.firstWhere(visible.contains);
    return DeviceTableSettings(
      visible: visible,
      sort: sort,
      ascending: json['ascending'] != false,
    );
  }
}

class DeviceTablePreferences {
  DeviceTablePreferences([File? file])
    : file =
          file ??
          File(
            '${Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}\\SubnetDesk Deploy\\device-table.json',
          );
  final File file;
  Future<DeviceTableSettings> load() async {
    if (!await file.exists()) return DeviceTableSettings();
    return DeviceTableSettings.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> save(DeviceTableSettings settings) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }
}

int _natural(String a, String b) {
  final parts = RegExp(r'\d+|\D+');
  final left = parts.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final right = parts.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = BigInt.tryParse(left[i]), y = BigInt.tryParse(right[i]);
    final comparison = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (comparison != 0) return comparison;
  }
  return left.length.compareTo(right.length);
}

int _version(String a, String b) {
  final pattern = RegExp(r'^\d+(\.\d+)*$');
  if (!pattern.hasMatch(a) || !pattern.hasMatch(b)) return _natural(a, b);
  final left = a.split('.').map(BigInt.parse).toList(),
      right = b.split('.').map(BigInt.parse).toList();
  for (var i = 0; i < left.length || i < right.length; i++) {
    final c = (i < left.length ? left[i] : BigInt.zero).compareTo(
      i < right.length ? right[i] : BigInt.zero,
    );
    if (c != 0) return c;
  }
  return 0;
}

List<ManagedDevice> sortManagedInventory(
  List<ManagedDevice> devices,
  InventoryColumn column,
  bool ascending,
) {
  return List<ManagedDevice>.of(devices)..sort((a, b) {
    final left = column.value(a).trim(), right = column.value(b).trim();
    final leftDate = column == InventoryColumn.lastSeen
        ? DateTime.tryParse(left)
        : null;
    final rightDate = column == InventoryColumn.lastSeen
        ? DateTime.tryParse(right)
        : null;
    final leftMissing =
        left.isEmpty || column == InventoryColumn.lastSeen && leftDate == null;
    final rightMissing =
        right.isEmpty ||
        column == InventoryColumn.lastSeen && rightDate == null;
    if (leftMissing != rightMissing) return leftMissing ? 1 : -1;
    int comparison;
    if (column == InventoryColumn.lastSeen) {
      comparison = leftDate == null || rightDate == null
          ? 0
          : leftDate.compareTo(rightDate);
    } else if (column == InventoryColumn.helperVersion ||
        column == InventoryColumn.agentVersion) {
      comparison = _version(left, right);
    } else if (column == InventoryColumn.address) {
      final x = InternetAddress.tryParse(left),
          y = InternetAddress.tryParse(right);
      if (x != null && y != null) {
        comparison = x.rawAddress.length.compareTo(y.rawAddress.length);
        for (var i = 0; comparison == 0 && i < x.rawAddress.length; i++) {
          comparison = x.rawAddress[i].compareTo(y.rawAddress[i]);
        }
      } else {
        comparison = x != null
            ? -1
            : y != null
            ? 1
            : _natural(left, right);
      }
    } else {
      comparison = _natural(left, right);
    }
    if (comparison == 0) return a.id.compareTo(b.id);
    return ascending ? comparison : -comparison;
  });
}
