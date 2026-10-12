import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/lan_approval_panel.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    String scope,
    Future<String> Function(bool, Map<String, bool>) decide,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LanApprovalPanel(
          name: 'phone',
          source: '192.0.2.1',
          scope: scope,
          ready: true,
          translateText: (s) => s,
          onDecision: (_) async =>
              throw StateError('legacy grant must not run'),
          onDecisionWithPermissions: decide,
        ),
      ),
    ),
  );

  testWidgets('new screen request defaults to view only', (tester) async {
    Map<String, bool>? permissions;
    await mount(tester, 'Screen sharing and control', (_, p) async {
      permissions = p;
      return '';
    });
    await tester.tap(find.byKey(const ValueKey('lan-approve')));
    await tester.pump();
    expect(permissions, {'keyboard': false, 'clipboard': false, 'file': false});
  });
  testWidgets('control selection does not grant clipboard or files', (
    tester,
  ) async {
    Map<String, bool>? permissions;
    await mount(tester, 'Screen sharing and control', (_, p) async {
      permissions = p;
      return '';
    });
    await tester.tap(find.text('Control'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lan-approve')));
    await tester.pump();
    expect(permissions, {'keyboard': true, 'clipboard': false, 'file': false});
  });
  testWidgets('file-only request requires explicit file selection', (
    tester,
  ) async {
    Map<String, bool>? permissions;
    await mount(tester, 'File transfer', (_, p) async {
      permissions = p;
      return '';
    });
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('lan-approve')))
          .onPressed,
      isNull,
    );
    expect(find.text('Control'), findsNothing);
    await tester.tap(find.text('Transfer file'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lan-approve')));
    await tester.pump();
    expect(permissions, {'keyboard': false, 'clipboard': false, 'file': true});
  });
  testWidgets('deny stays available without selecting permissions', (
    tester,
  ) async {
    bool? decision;
    await mount(tester, 'File transfer', (accept, _) async {
      decision = accept;
      return '';
    });
    await tester.tap(find.byKey(const ValueKey('lan-deny')));
    await tester.pump();
    expect(decision, false);
  });
  testWidgets('advanced requests require explicit requested-access approval', (tester) async {
    Map<String, bool>? permissions;
    await mount(tester, 'Terminal', (_, p) async { permissions = p; return ''; });
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('lan-approve'))).onPressed, isNull);
    expect(find.text('Transfer file'), findsNothing);
    await tester.tap(find.text('Allow requested access'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lan-approve')));
    await tester.pump();
    expect(permissions, {'keyboard': true, 'clipboard': false, 'file': false});
  });
}
