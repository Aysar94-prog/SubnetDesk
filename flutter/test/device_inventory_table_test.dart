import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/device_inventory_table.dart';
import 'package:flutter_hbb/desktop/management_models.dart';

ManagedDevice row(String id, Map<String, dynamic> values) =>
    ManagedDevice({'id': id, ...values});
List<String> ids(
  List<ManagedDevice> rows,
  InventoryColumn column,
  bool ascending,
) => sortManagedInventory(rows, column, ascending).map((d) => d.id).toList();

void main() {
  test(
    'name, numeric versions and IP addresses sort naturally in both directions',
    () {
      final rows = [
        row('a', {
          'name': 'PC-2',
          'agentVersion': '1.3.9',
          'helperVersion': '1.9.0',
          'address': '192.168.50.2',
        }),
        row('b', {
          'name': 'pc-10',
          'agentVersion': '1.3.10',
          'helperVersion': '1.10.0',
          'address': '192.168.50.10',
        }),
        row('missing', {}),
      ];
      for (final column in [
        InventoryColumn.device,
        InventoryColumn.agentVersion,
        InventoryColumn.helperVersion,
        InventoryColumn.address,
      ]) {
        expect(ids(rows, column, true), ['a', 'b', 'missing']);
        expect(ids(rows, column, false), ['b', 'a', 'missing']);
      }
      expect(rows.first.id, 'a');
    },
  );
  test(
    'last seen uses actual timestamps, handles zones and leaves unknown values last',
    () {
      final rows = [
        row('old', {'lastSeenUtc': '2026-10-24T10:01:00Z'}),
        row('new', {'lastSeenUtc': '2026-10-24T12:02:00+02:00'}),
        row('domain', {
          'transport': 'domain',
          'checkedUtc': '2026-10-24T10:03:00Z',
          'lastSeenUtc': '2020-01-01T00:00:00Z',
        }),
        row('invalid', {'lastSeenUtc': 'invalid'}),
      ];
      expect(ids(rows, InventoryColumn.lastSeen, true), [
        'old',
        'new',
        'domain',
        'invalid',
      ]);
      expect(ids(rows, InventoryColumn.lastSeen, false), [
        'domain',
        'new',
        'old',
        'invalid',
      ]);
    },
  );
  test(
    'all inventory fields are comparable and stable for a 600-device fleet',
    () {
      final rows = List.generate(
        600,
        (i) => row('$i', {
          'name': 'PC-${600 - i}',
          'machine': 'HOST-$i',
          'address': '10.0.${i ~/ 250}.${i % 250 + 1}',
          'agentVersion': '1.4.${i % 12}',
          'operatingSystem': 'Windows 11 Pro 24H2',
          'architecture': 'x64',
          'domainJoined': i.isEven,
          'group': 'Group ${i % 4}',
          'status': 'Succeeded',
          'lastSeenUtc': DateTime.utc(
            2026,
            10,
            24,
          ).add(Duration(minutes: i)).toIso8601String(),
        }),
      );
      for (final column in InventoryColumn.values) {
        final sorted = sortManagedInventory(rows, column, true);
        expect(sorted.length, 600);
        expect(sorted.map((d) => d.id).toSet().length, 600);
        expect(
          ids(rows, column, true),
          ids(rows.reversed.toList(), column, true),
        );
        expect(sortManagedInventory(rows, column, false).length, 600);
      }
      expect(
        sortManagedInventory(rows, InventoryColumn.device, true).first.name,
        'PC-1',
      );
    },
  );
  test(
    'preferences persist visible columns and sorting, and tolerate stale column IDs',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'SubnetDesk-table-test-',
      );
      try {
        final file = File('${folder.path}/table.json');
        final preferences = DeviceTablePreferences(file);
        expect(
          (await preferences.load()).visible,
          DeviceTableSettings.defaults,
        );
        final settings = DeviceTableSettings(
          visible: {
            InventoryColumn.device,
            InventoryColumn.agentVersion,
            InventoryColumn.lastSeen,
          },
          sort: InventoryColumn.lastSeen,
          ascending: false,
        );
        await preferences.save(settings);
        final restored = await DeviceTablePreferences(file).load();
        expect(restored.toJson(), settings.toJson());
        final stale = DeviceTableSettings.fromJson({
          'visible': ['agentVersion', 'removed'],
          'sort': 'removed',
          'ascending': false,
        });
        expect(stale.columns, [InventoryColumn.agentVersion]);
        expect(stale.sort, InventoryColumn.agentVersion);
        expect(
          DeviceTableSettings.fromJson({'visible': []}).visible,
          DeviceTableSettings.defaults,
        );
      } finally {
        await folder.delete(recursive: true);
      }
    },
  );
}
