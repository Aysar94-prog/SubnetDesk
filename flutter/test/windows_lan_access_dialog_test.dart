import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/windows_lan_access_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester,
      void Function(WindowsLanAccessSelection?) result, {bool saved = false, bool edit = false}) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(child: const Text('Open'), onPressed: () async {
        result(await showDialog<WindowsLanAccessSelection>(context: context,
          builder: (_) => WindowsLanAccessDialog(endpoint: '192.0.2.1:21118',
            editEndpoint: edit, translateText: (s) => s,
            hasSavedPassword: (endpoint) => saved && endpoint == '192.0.2.1:21118')));
      }),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('windows-lan-connect')));
    await tester.pumpAndSettle();
  }
  testWidgets('one field, no method menu, preserves password and remember', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (v) => result = v);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('windows-lan-password')), 'synthetic-password');
    await tester.tap(find.byType(CheckboxListTile));
    await submit(tester);
    expect(jsonDecode(result!.payload!), {'lan_version': 1, 'username': '',
      'password': 'synthetic-password', 'remember': true, 'auto_access': true});
  });
  testWidgets('six digit input tries password before code', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (v) => result = v);
    await tester.enterText(find.byKey(const ValueKey('windows-lan-password')), '654321');
    await submit(tester);
    final data = jsonDecode(result!.payload!);
    expect(data['password'], '654321');
    expect(data['auto_access'], true);
    expect(data.containsKey('temporary_code'), false);
  });
  testWidgets('empty input requests manual approval', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (v) => result = v);
    await submit(tester);
    expect(jsonDecode(result!.payload!), {'lan_version': 1, 'access_method': 2, 'temporary_code': ''});
  });
  testWidgets('saved password shows mask without putting secret in controller', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (v) => result = v, saved: true);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('windows-lan-password')));
    expect(field.controller!.text, isEmpty);
    expect(field.decoration!.hintText, '********');
    expect(find.text('Saved password will be used'), findsOneWidget);
    await submit(tester);
    expect(result!.payload, isNull);
  });
  testWidgets('clear saved selection permits manual approval', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (v) => result = v, saved: true);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    await submit(tester);
    expect(jsonDecode(result!.payload!)['access_method'], 2);
  });
  testWidgets('endpoint change drops saved selection', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (v) => result = v, saved: true, edit: true);
    await tester.enterText(find.byKey(const ValueKey('windows-lan-endpoint')), '192.0.2.2');
    await submit(tester);
    expect(jsonDecode(result!.payload!)['access_method'], 2);
  });
  testWidgets('compact dialog does not overflow', (tester) async {
    tester.view.physicalSize = const Size(440, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, (_) {}, edit: true);
    expect(tester.takeException(), isNull);
    await submit(tester);
    expect(tester.takeException(), isNull);
  });
}
