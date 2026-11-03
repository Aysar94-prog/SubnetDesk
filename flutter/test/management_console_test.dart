import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_hbb/desktop/agent_management.dart';
import 'package:flutter_hbb/desktop/management_models.dart';
import 'package:flutter_hbb/desktop/device_inventory_table.dart';
import 'package:flutter_hbb/desktop/remote_helper_deployment.dart';
import 'package:flutter_hbb/desktop/pages/management_console_page.dart';

class PackageDeleteFixture extends FleetFixture {
  bool removed = false;
  int deletes = 0;
  @override
  Future<Map<String, dynamic>> call(String route, {Object? body, File? file}) async {
    if (route == 'packages') return {'packages': removed ? [] : [
      {'version':'1.4.5.120','sha256':'A' * 64,'productCode':'fixture',
       'uploadedUtc':DateTime.now().toUtc().toIso8601String()}]};
    if (route == 'packages/remove') {
      expect((body as Map)['sha256'], 'A' * 64);
      deletes++; removed = true; return {'ok':true};
    }
    return super.call(route, body: body, file: file);
  }
}

class DeleteFixture extends FleetFixture {
  DeleteFixture() : super(size: 1);
  final mutations = <String>[];
  bool removed = false;
  @override
  Future<Map<String, dynamic>> call(String route, {Object? body, File? file}) async {
    if (route == 'revoke' || route == 'device/remove') {
      mutations.add(route);
      if (route == 'device/remove') removed = true;
      return {'ok': true};
    }
    final result = await super.call(route, body: body, file: file);
    if (route == 'devices') {
      final devices = result['devices'] as List;
      if (removed) devices.clear();
      else (devices.first as Map)['transport'] = 'agent';
    }
    return result;
  }
}

class FleetFixture extends AgentManagementClient {
  FleetFixture({this.size = 60})
    : super({
        'server': 'https://console.example/subnetdesk/',
        'certificateSha256': '0' * 64,
        'adminToken': 'fixture',
      });
  final int size;
  @override
  Future<Map<String, dynamic>> call(
    String route, {
    Object? body,
    File? file,
  }) async {
    if (route == 'devices')
      return {
        'devices': List.generate(
          size,
          (i) => {
            'id': '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
            'name':
                ['FINANCE', 'ENGINEERING', 'RECEPTION', 'LAB', 'OPERATIONS'][i %
                    5] +
                '-${(i + 1).toString().padLeft(3, '0')}',
            'machine': 'WS-${i + 1}',
            'operatingSystem':
                'Microsoft Windows 10 Pro 22H2 (Build 19045.6000)',
            'address': 'ws-${i + 1}.example.local',
            'transport': i % 3 == 0 ? 'domain' : 'agent',
            'online': i % 6 != 0,
            'status': i == 5 ? 'Failed' : 'Succeeded',
            'helperVersion': '1.4.4.104',
            'helperService': i == 5 ? 'Stopped' : 'Running',
            'agentVersion': '1.2.0',
            'group': ['Head office', 'Engineering', 'Branch office'][i % 3],
            'lastSeenUtc': DateTime.now()
                .subtract(Duration(minutes: i % 6 == 0 ? 18 : 0))
                .toUtc()
                .toIso8601String(),
            'checkedUtc': DateTime.now().toUtc().toIso8601String(),
            'connectionState': i % 6 == 0 ? 'unknown' : 'ready',
            'message': i == 5
                ? 'Installation requires administrator attention.'
                : 'Helper version and service verified.',
            'job': null,
          },
        ),
      };
    if (route == 'history')
      return {
        'history': List.generate(
          6,
          (i) => {
            'deviceId':
                '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
            'job': {
              'action': ['install', 'repair', 'restart'][i % 3],
            },
            'ok': i != 5,
            'message': i == 5
                ? 'Service verification failed. Review device details.'
                : 'Selected Helper version and service verified.',
            'finishedUtc': DateTime.now()
                .subtract(Duration(minutes: 3 + i * 5))
                .toUtc()
                .toIso8601String(),
          },
        ),
      };
    if (route == 'packages') return {'packages': []};
    return {'ok': true};
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('console-render')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('../output/console-visual-checks');
    await folder.create(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class ApprovalFixture extends FleetFixture {
  ApprovalFixture() : super(size: 0);
  final pending = List.generate(600, (i) => '$i').toSet();
  int approved = 0, rejected = 0;
  @override
  Future<Map<String, dynamic>> call(
    String route, {
    Object? body,
    File? file,
  }) async {
    if (route == 'requests')
      return {
        'requests': pending
            .map(
              (id) => {
                'id': id,
                'machine': 'NEW-PC-$id',
                'domain': 'WORKGROUP',
                'address': '192.0.2.10',
                'verification': 'AABBCCDDEEFF',
                'createdUtc': '2026-10-23T15:20:00Z',
              },
            )
            .toList(),
      };
    if (route == 'requests/approve' || route == 'requests/reject') {
      pending.remove((body as Map)['deviceId']);
      if (route.endsWith('approve')) {
        approved++;
      } else {
        rejected++;
      }
      return {'ok': true};
    }
    return super.call(route, body: body, file: file);
  }
}

class TablePreferencesFixture extends DeviceTablePreferences {
  DeviceTableSettings stored = DeviceTableSettings(
    visible: {
      InventoryColumn.device,
      InventoryColumn.agentVersion,
      InventoryColumn.lastSeen,
    },
    sort: InventoryColumn.lastSeen,
    ascending: false,
  );
  @override
  Future<DeviceTableSettings> load() async => stored;
  @override
  Future<void> save(DeviceTableSettings settings) async {
    stored = settings;
  }
}

class AgentUpdatesFixture extends FleetFixture {
  AgentUpdatesFixture() : super(size: 3);
  Map? queued;
  @override
  Future<Map<String, dynamic>> call(
    String route, {
    Object? body,
    File? file,
  }) async {
    if (route == 'agent-packages')
      return {
        'packages': [
          {
            'version': '1.4.1.0',
            'sha256': 'F' * 64,
            'uploadedUtc': '2026-10-23T15:20:00Z',
          },
        ],
      };
    if (route == 'jobs') {
      queued = body as Map;
      return {
        'results': (queued!['deviceIds'] as List)
            .map((id) => {'id': id, 'queued': true})
            .toList(),
      };
    }
    return super.call(route, body: body, file: file);
  }
}

void main() {
  testWidgets('library package deletion requires confirmation and refreshes library', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = PackageDeleteFixture();
    await tester.pumpWidget(MaterialApp(home: ManagementConsolePage(
        rememberTable:false, connect:() async => fixture)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Helper packages').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Delete package'));
    await tester.tap(find.byTooltip('Delete package'));
    await tester.pump(const Duration(milliseconds:400));
    expect(fixture.deletes, 0);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(fixture.deletes, 0);
    await tester.tap(find.byTooltip('Delete package'));
    await tester.pump(const Duration(milliseconds:400));
    await tester.tap(find.text('Confirm').last);
    await tester.pumpAndSettle();
    expect(fixture.deletes, 1);
    expect(find.text('No releases in the library'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('delete Agent confirms then revokes and removes its record', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = DeleteFixture();
    await tester.pumpWidget(MaterialApp(home: ManagementConsolePage(
        rememberTable: false, connect: () async => fixture)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devices').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete device'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(fixture.mutations, isEmpty);
    expect(find.textContaining('Agent access will also be revoked'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(fixture.mutations, isEmpty);
    await tester.ensureVisible(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete device'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Confirm').last);
    await tester.pumpAndSettle();
    expect(fixture.mutations, ['revoke', 'device/remove']);
    expect(fixture.removed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'device-wide receiver unlock requires its current password and excludes unattended credentials',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AgentUpdatesFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ManagementConsolePage(
            rememberTable: false,
            connect: () async => fixture,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agent managed  2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all 2 results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Helper security settings'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.text('Unlock all accounts to send-and-receive').last,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('every Windows account'), findsOneWidget);
      await tester.tap(find.text('Queue receiver policy'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Enter the current receiver unlock password.'),
        findsOneWidget,
      );
      expect(fixture.queued, isNull);
      final field = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Current receiver unlock password',
      );
      await tester.enterText(field, 'synthetic-device-password');
      await tester.tap(find.text('Queue receiver policy'));
      await tester.pumpAndSettle();
      final settings = fixture.queued!['settings'] as Map;
      expect(settings['operation'], 'receiver-unlock');
      expect(settings['currentPassword'], 'synthetic-device-password');
      expect(settings.containsKey('newPassword'), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'unattended password changes are explicit and validated before queuing',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AgentUpdatesFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ManagementConsolePage(
            rememberTable: false,
            connect: () async => fixture,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agent managed  2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all 2 results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Helper security settings'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Queue password change'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Enter a password of 1–180 UTF-8 bytes.'),
        findsOneWidget,
      );
      expect(fixture.queued, isNull);
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(
        field('New unattended password'),
        'synthetic-ui-password',
      );
      await tester.enterText(field('Confirm new password'), 'different');
      await tester.tap(find.text('Queue password change'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('The new password and confirmation do not match.'),
        findsOneWidget,
      );
      await tester.enterText(
        field('Confirm new password'),
        'synthetic-ui-password',
      );
      await tester.tap(find.text('Queue password change'));
      await tester.pumpAndSettle();
      expect(fixture.queued!['action'], 'configure-helper');
      expect(
        (fixture.queued!['settings'] as Map)['operation'],
        'unattended-password',
      );
      expect(
        (fixture.queued!['settings'] as Map)['newPassword'],
        'synthetic-ui-password',
      );
      expect((fixture.queued!['deviceIds'] as List).length, 2);
      expect(find.text('synthetic-ui-password'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'MSI installation offers a separate optional unattended password',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AgentUpdatesFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ManagementConsolePage(
            rememberTable: false,
            initialHelperPackage: const HelperMsiPackage(
              'fixture.msi',
              '1.4.4.104',
              'fixture',
              'fixture',
            ),
            connect: () async => fixture,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agent managed  2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all 2 results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install / update Helper'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Set unattended access password'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Unattended access password',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm install'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Enter a password of 1–180 UTF-8 bytes.'),
        findsOneWidget,
      );
      expect(fixture.queued, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'saved columns and sorting are restored when the console reopens',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = TablePreferencesFixture();
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ManagementConsolePage(
              tablePreferences: preferences,
              connect: () async => FleetFixture(size: 3),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Devices'));
        await tester.pumpAndSettle();
      }

      await open();
      DataTable table() => tester.widget<DataTable>(find.byType(DataTable));
      expect(table().columns.length, 4);
      expect(table().sortColumnIndex, 2);
      expect(table().sortAscending, false);
      await tester.tap(find.text('AGENT VERSION'));
      await tester.pumpAndSettle();
      expect(preferences.stored.sort, InventoryColumn.agentVersion);
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all'));
      await tester.tap(find.text('Apply columns'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await open();
      expect(table().columns.length, InventoryColumn.values.length + 1);
      expect(
        table().sortColumnIndex,
        InventoryColumn.values.indexOf(InventoryColumn.agentVersion),
      );
      expect(preferences.stored.visible.length, InventoryColumn.values.length);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all device columns sort and visibility can be changed without losing selection',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = FleetFixture(size: 60);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const Key('console-render'),
            child: ManagementConsolePage(
              rememberTable: false,
              connect: () async => fixture,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Devices'));
      await tester.pumpAndSettle();
      DataTable table() => tester.widget<DataTable>(find.byType(DataTable));
      expect(table().columns.length, DeviceTableSettings.defaults.length + 1);
      expect(find.text('AGENT VERSION'), findsOneWidget);
      expect(find.text('WINDOWS VERSION'), findsOneWidget);
      await tester.tap(find.text('Select all 60 results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEVICE'));
      await tester.pumpAndSettle();
      expect(table().sortAscending, false);
      final data = await fixture.call('devices');
      final expected = sortManagedInventory(
        (data['devices'] as List)
            .map((r) => ManagedDevice(Map<String, dynamic>.from(r)))
            .toList(),
        InventoryColumn.device,
        false,
      );
      expect(table().rows.first.key, ValueKey(expected.first.id));
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      final windows = find.byKey(
        const ValueKey('column-choice-operatingSystem'),
      );
      await tester.ensureVisible(windows);
      await tester.pumpAndSettle();
      await tester.tap(windows);
      await tester.tap(find.text('Apply columns'));
      await tester.pumpAndSettle();
      expect(find.text('WINDOWS VERSION'), findsNothing);
      expect(find.text('60 selected'), findsOneWidget);
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all'));
      await tester.tap(find.text('Apply columns'));
      await tester.pumpAndSettle();
      expect(table().columns.length, InventoryColumn.values.length + 1);
      for (var i = 0; i < InventoryColumn.values.length; i++) {
        expect(table().columns[i].onSort, isNotNull);
        table().columns[i].onSort!(i, false);
        await tester.pumpAndSettle();
        expect(table().sortColumnIndex, i);
        expect(table().sortAscending, false);
      }
      await capture(tester, 'inventory-all-columns');
      expect(find.text('60 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Agent updates use a separate library and queue only Agent devices',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AgentUpdatesFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const Key('console-render'),
            child: ManagementConsolePage(
              rememberTable: false,
              connect: () async => fixture,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all 3 results'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agent updates'));
      await tester.pumpAndSettle();
      expect(find.text('SubnetDesk Agent 1.4.1.0'), findsOneWidget);
      await tester.tap(find.text('Select').last);
      await tester.pumpAndSettle();
      await capture(tester, 'agent-updates');
      await tester.tap(find.text('Queue Agent update'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update Agent on 2 devices?'), findsOneWidget);
      expect(fixture.queued, isNull);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(fixture.queued!['action'], 'agent-update');
      expect((fixture.queued!['deviceIds'] as List).length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '600 pending Agent requests require explicit administrator approval',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = ApprovalFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const Key('console-render'),
            child: ManagementConsolePage(
              rememberTable: false,
              connect: () async => fixture,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('600 computers are waiting for approval'),
        findsOneWidget,
      );
      await tester.tap(find.text('Review requests'));
      await tester.pumpAndSettle();
      expect(find.text('600 pending requests'), findsOneWidget);
      await capture(tester, 'agent-requests');
      await tester.tap(find.text('Select all requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve selected (600)'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.approved, 0);
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(fixture.approved, 600);
      expect(find.text('0 pending requests'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  setUpAll(() async {
    PackageInfo.setMockInitialValues(appName: 'SubnetDesk Deploy', packageName: 'subnetdesk.deploy', version: '1.9.2', buildNumber: '122', buildSignature: '');
    if (Platform.isWindows) {
      final font = FontLoader('Segoe UI');
      font.addFont(
        File(
          r'C:\Windows\Fonts\segoeui.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        r'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await icons.load();
  });
  test(
    'unified inventory filters 600 devices without conflating management types',
    () {
      final devices = List.generate(
        600,
        (i) => ManagedDevice({
          'id': '$i',
          'name': 'PC-$i',
          'transport': i.isEven ? 'agent' : 'domain',
          'online': i % 3 == 0,
          'group': i < 100 ? 'HQ' : 'Branch',
        }),
      );
      expect(filterManagedDevices(devices, transport: 'agent').length, 300);
      expect(filterManagedDevices(devices, transport: 'domain').length, 300);
      expect(filterManagedDevices(devices, status: 'online').length, 200);
      expect(filterManagedDevices(devices, group: 'HQ').length, 100);
      expect(filterManagedDevices(devices, query: 'PC-599').single.id, '599');
      expect(
        ManagedDevice({
          'transport': 'domain',
          'connectionState': 'failed',
        }).connection,
        'Check failed',
      );
      expect(
        ManagedDevice({
          'transport': 'agent',
          'online': true,
          'revoked': true,
        }).online,
        false,
      );
    },
  );
  testWidgets(
    'console overview and unified inventory render with pagination and search',
    (tester) async {
      tester.view.reset();
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = FleetFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const Key('console-render'),
            child: ManagementConsolePage(
              rememberTable: false,
              connect: () async => fixture,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your device fleet, in one place'), findsOneWidget);
      expect(find.text('Server connected'), findsOneWidget);
      expect(find.text('Deploy 1.9.2 · Build 122'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'overview');
      await tester.tap(find.text('Devices').first);
      await tester.pumpAndSettle();
      expect(find.text('1–25 of 60 devices'), findsOneWidget);
      await capture(tester, 'devices');
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField).first, 'FINANCE-001');
      await tester.pumpAndSettle();
      expect(find.text('1–1 of 1 devices'), findsOneWidget);
      expect(find.text('FINANCE-001', skipOffstage: true), findsNWidgets(2));
      await tester.tap(find.text('FINANCE-001').last);
      await tester.pumpAndSettle();
      expect(find.text('Computer name'), findsOneWidget);
      expect(find.text('WS-1'), findsOneWidget);
      expect(
        find.text('Microsoft Windows 10 Pro 22H2 (Build 19045.6000)'),
        findsNWidgets(2),
      );
      await capture(tester, 'device-os-details');
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks & history').first);
      await tester.pumpAndSettle();
      expect(find.text('Completed activity'), findsOneWidget);
      await capture(tester, 'tasks');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('600-device bulk selection and filters fit the compact console', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = FleetFixture(size: 600);
    await tester.pumpWidget(
      MaterialApp(
        home: ManagementConsolePage(
          rememberTable: false,
          connect: () async => fixture,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Devices'));
    await tester.pumpAndSettle();
    expect(find.text('1–25 of 600 devices'), findsOneWidget);
    await tester.tap(find.text('Select all 600 results'));
    await tester.pumpAndSettle();
    expect(find.text('600 selected'), findsOneWidget);
    await tester.tap(find.text('Domain / WinRM  200'));
    await tester.pumpAndSettle();
    expect(find.text('1–25 of 200 devices'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('unconfigured console displays a real empty/error state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ManagementConsolePage(
          rememberTable: false,
          connect: () async =>
              throw const FileSystemException('Unavailable test configuration'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Devices'));
    await tester.pumpAndSettle();
    expect(find.text('Build your device inventory'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
