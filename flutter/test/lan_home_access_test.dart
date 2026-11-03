import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/lan_unattended_access.dart';

void main() {
  // Source-wiring regression specifically catches build82's wrong home branch.
  // This complements rendered-card tests; real full-home acceptance is separate.
  test('actual normal and incoming-only home branches both mount the code card', () {
    final home = File('lib/desktop/pages/desktop_home_page.dart').readAsStringSync();
    final normal = home.substring(home.indexOf('Widget _buildNavigationSidebar('),
      home.indexOf('Widget _buildSidebarItem('));
    final incoming = home.substring(home.indexOf('Widget buildLeftPane('),
      home.indexOf('  buildRightPane('));
    expect(normal, contains('const LanOptionalAccess()'));
    expect(incoming, contains('const LanOptionalAccess()'));
    expect(normal.indexOf('const LanOptionalAccess()'), lessThan(normal.indexOf('_buildSidebarItem(')));
    final settings = File('lib/desktop/pages/desktop_setting_page.dart').readAsStringSync();
    expect(settings, contains("_Card(title: 'Unattended access'"));
    expect(settings, contains('const LanUnattendedAccess()'));
  });
  Future<void> show(WidgetTester tester, Map<String, dynamic> info,
    Future<String> Function(bool, String) save) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: LanUnattendedAccess(readState: () async => jsonEncode(info), save: save,
        translateText: (text) => text)))));
    await tester.pump();
  }
  testWidgets('unattended settings have one obscured password and no username', (tester) async {
    await show(tester, {'configured': true, 'password_access_enabled': true}, (_, __) async => '');
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Leave blank to keep current password'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('fresh receiver cannot enable a blank unattended password', (tester) async {
    var saves = 0;
    await show(tester, {'configured': false}, (_, __) async { saves++; return ''; });
    await tester.tap(find.byType(CheckboxListTile)); await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-unattended'))); await tester.pump();
    expect(saves, 0);
    expect(find.text('Set an unattended access password before enabling password access'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('disable sends explicit choice but blank password preserves configured secret', (tester) async {
    final choices = <List<Object>>[];
    await show(tester, {'configured': true, 'password_access_enabled': true}, (enabled, password) async {
      choices.add([enabled, password]); return '';
    });
    await tester.tap(find.byType(CheckboxListTile)); await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-unattended'))); await tester.pump();
    expect(choices, [[false, '']]);
    await tester.pumpWidget(const SizedBox());
  });
}
