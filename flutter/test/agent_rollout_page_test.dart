import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/agent_management.dart';
import 'package:flutter_hbb/desktop/pages/agent_rollout_page.dart';

final captureKey = GlobalKey();

class RolloutFixture extends AgentManagementClient {
  RolloutFixture() : super({'server': 'https://management.example/subnetdesk/', 'certificateSha256': 'A' * 64, 'adminToken': 'fixture'});
  final mutations = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> jobs = [];
  final profiles = <Map<String, dynamic>>[{'id': 'profile', 'name': 'IT administration', 'username': 'Administrator', 'accountType': 'local'}];
  @override
  Future<Map<String, dynamic>> call(String route, {Object? body, File? file}) async {
    if (body != null) mutations.add({'route': route, ...Map<String, dynamic>.from(body as Map)});
    if (route == 'rollout/profile') {
      final input = Map<String, dynamic>.from(body as Map);
      final saved = {'id': input['id'] ?? 'new-profile', 'name': input['name'], 'username': input['username'], 'accountType': input['accountType']};
      profiles.removeWhere((p) => p['id'] == saved['id']); profiles.add(saved); return saved;
    }
    if (route == 'rollout/profile-delete') { profiles.removeWhere((p) => p['id'] == (body as Map)['id']); return {'ok': true}; }
    if (route == 'rollout/status') return {
      'devices': [
        ...List.generate(600, (i) => {'id': 'device-$i', 'machine': 'WINDOWS-${i.toString().padLeft(3, '0')}',
          'target': '192.0.${i ~/ 254}.${1 + i % 254}', 'uuid': 'hardware-$i', 'verifiedWindows': true,
          'windowsVersion': 'Windows 11 Pro', 'agentService': 'Not installed', 'verifiedUtc': '2026-10-25T10:00:00Z'}),
        {'id': 'unverified', 'machine': 'LINUX-UNVERIFIED', 'verifiedWindows': false},
      ],
      'profiles': profiles,
      'schedules': [], 'jobs': jobs,
    };
    return {'ok': true};
  }
}

Future<void> open(WidgetTester tester, RolloutFixture api) async {
  tester.view.physicalSize = const Size(1450, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Segoe UI', colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff008b98))), home: RepaintBoundary(key: captureKey, child: Scaffold(body: SingleChildScrollView(
    child: AgentRolloutPage(connect: () async => api, onRequests: () {}))))));
  await tester.pumpAndSettle();
}
Future<void> capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../output/console-visual-checks'); await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
Future<void> press(WidgetTester tester, String text) async {
  final target = find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first;
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 400));
}
void main() {
  setUpAll(() async {
    final font = FontLoader('Segoe UI');
    font.addFont(Future.value(ByteData.sublistView(await File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytes())));
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(await File(r'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf').readAsBytes())));
    await icons.load();
  });
  testWidgets('Windows-only inventory selects all 600 across pages and pushes explicit identities', (tester) async {
    final api = RolloutFixture(); await open(tester, api);
    expect(find.text('LINUX-UNVERIFIED'), findsNothing);
    expect(find.text('600 Windows devices · page 1 of 24'), findsOneWidget);
    await capture(tester, 'agent-rollout-credentials');
    await press(tester, 'Select all 600 results');
    await capture(tester, 'agent-rollout-600-windows');
    await press(tester, 'Push Agent to 600 selected');
    expect(find.text('Push Agent to 600 Windows devices?'), findsOneWidget);
    expect(api.mutations, isEmpty);
    await press(tester, 'Confirm'); await tester.pumpAndSettle();
    final sent = api.mutations.single;
    expect(sent['route'], 'rollout/push');
    expect((sent['deviceIds'] as List).length, 600);
    expect(sent.containsKey('password'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('discovery and push schedules send separate persisted plans and UTC times', (tester) async {
    final api = RolloutFixture(); await open(tester, api);
    final ranges = find.widgetWithText(TextField, 'VLAN/subnet ranges or hostnames — one per line');
    await tester.enterText(ranges, '192.168.50.0/24\n192.168.60.0/24');
    await press(tester, 'Schedule discovery');
    await tester.enterText(find.widgetWithText(TextField, 'Repeat every (minutes)'), '60');
    await press(tester, 'Save schedule'); await tester.pumpAndSettle();
    await press(tester, 'Select all 600 results');
    await press(tester, 'Schedule push');
    await tester.enterText(find.widgetWithText(TextField, 'Repeat every (minutes)'), '1440');
    await press(tester, 'Save schedule'); await tester.pumpAndSettle();
    expect(api.mutations.length, 2);
    final pull = api.mutations[0], push = api.mutations[1];
    expect(pull['kind'], 'discover'); expect(pull['intervalMinutes'], 60);
    expect(pull['ranges'], contains('192.168.60.0/24')); expect(pull.containsKey('deviceIds'), isFalse);
    expect(push['kind'], 'push'); expect(push['intervalMinutes'], 1440);
    expect((push['deviceIds'] as List).length, 600); expect(push.containsKey('ranges'), isFalse);
    expect(DateTime.parse(push['nextRunUtc'] as String).isUtc, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('all Windows inventory columns expose sorting', (tester) async {
    final api = RolloutFixture(); await open(tester, api);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns.length, 6);
    expect(table.columns.every((c) => c.onSort != null), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('discovery failures display counts, error codes and target examples', (tester) async {
    final api = RolloutFixture();
    api.jobs = [{'kind': 'discover', 'state': 'completed', 'completed': '40', 'total': '40', 'failed': '40', 'windows': '0',
      'failures': [{'count': 40, 'message': 'WMI/RPC unavailable (0x800706BA)', 'targets': ['192.0.2.1', '192.0.2.2']}]}];
    await open(tester, api);
    expect(find.text('40 targets: WMI/RPC unavailable (0x800706BA)\nExamples: 192.0.2.1, 192.0.2.2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('password visibility toggles and duplicate profile names are rejected before saving', (tester) async {
    final api = RolloutFixture(); await open(tester, api);
    final password = find.widgetWithText(TextField, 'Windows password');
    await tester.enterText(password, 'typed-test-secret');
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password')); await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password')); await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.enterText(find.widgetWithText(TextField, 'Profile name'), '  it ADMINISTRATION  ');
    await press(tester, 'Save credential profile'); await tester.pumpAndSettle();
    expect(find.textContaining('A credential profile with this name already exists.'), findsOneWidget);
    expect(api.mutations, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('profiles edit in place, preserve an unchanged password and delete only after confirmation', (tester) async {
    final api = RolloutFixture(); await open(tester, api);
    await press(tester, 'Edit selected profile'); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Profile name')).controller!.text, 'IT administration');
    await tester.enterText(find.widgetWithText(TextField, 'Profile name'), 'Renamed IT');
    await press(tester, 'Update credential profile'); await tester.pumpAndSettle();
    expect(api.mutations.single['id'], 'profile'); expect(api.mutations.single['password'], '');
    expect(api.profiles.length, 1); expect(api.profiles.single['name'], 'Renamed IT');
    await Scrollable.ensureVisible(tester.element(find.byTooltip('Delete selected profile')));
    await tester.tap(find.byTooltip('Delete selected profile')); await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Delete credential profile?'), findsOneWidget);
    expect(api.mutations.length, 1);
    await press(tester, 'Cancel'); await tester.pumpAndSettle();
    expect(api.profiles.length, 1);
    await tester.tap(find.byTooltip('Delete selected profile')); await tester.pump(const Duration(milliseconds: 400));
    await press(tester, 'Confirm'); await tester.pumpAndSettle();
    expect(api.mutations.last['route'], 'rollout/profile-delete'); expect(api.profiles, isEmpty);
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Saved credential profile'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
