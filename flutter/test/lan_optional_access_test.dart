import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/lan_optional_access.dart';

void main() {
  Future<void> show(WidgetTester tester, Map<String, dynamic> state,
    Future<String> Function(bool, bool) setMethods,
    {Future<String> Function()? generate, bool settings = false}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 280, height: 250,
      child: SingleChildScrollView(child: LanOptionalAccess(readState: () async => jsonEncode(state),
        setMethods: setMethods, generateCode: generate, showSettings: settings,
        translateText: (text) => text))))));
    await tester.pump();
  }
  testWidgets('unavailable listener cannot enable passwordless methods', (tester) async {
    var changes = 0;
    await show(tester, {'available': false}, (_, __) async { changes++; return ''; }, settings: true);
    final tiles = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tiles.every((tile) => tile.onChanged == null && tile.value == false), isTrue);
    expect(changes, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('manual opt-in does not disable automatic code access', (tester) async {
    final changes = <List<bool>>[];
    await show(tester, {'available': true}, (code, manual) async {
      changes.add([code, manual]); return '';
    }, settings: true);
    await tester.tap(find.byType(CheckboxListTile).first); await tester.pump();
    expect(changes, [[true, true]]);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('temporary code fits a compact scrolling receiver pane', (tester) async {
    await show(tester, {'available': true, 'code_enabled': true, 'code': '012345',
      'expires_seconds': 119}, (_, __) async => '', generate: () async => '');
    expect(find.byKey(const ValueKey('lan-temporary-code')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Temporary code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home code reading never enables access or generates from polling', (tester) async {
    var changes = 0;
    var generations = 0;
    await show(tester, {'available': true, 'code_enabled': true, 'code': '012345',
      'expires_seconds': 119}, (_, __) async { changes++; return ''; },
      generate: () async { generations++; return ''; });
    await tester.pump(const Duration(seconds: 2));
    expect(changes, 0); expect(generations, 0);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
