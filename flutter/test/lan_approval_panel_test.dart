import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/lan_approval_panel.dart';

void main() {
  Future<void> show(WidgetTester tester, {bool ready = true,
    required Future<String> Function(bool) decide}) => tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LanApprovalPanel(name: 'claimed phone', source: '192.0.2.1',
        scope: 'Screen sharing and control', ready: ready, onDecision: decide,
        translateText: (text) => text))));
  testWidgets('pending request exposes decisions, not session operations', (tester) async {
    await show(tester, decide: (_) async => '');
    expect(find.byKey(const ValueKey('lan-approve')), findsOneWidget);
    expect(find.byKey(const ValueKey('lan-deny')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.textContaining('192.0.2.1'), findsOneWidget);
  });
  testWidgets('cannot approve before backend request metadata arrives', (tester) async {
    var decisions = 0;
    await show(tester, ready: false, decide: (_) async { decisions++; return ''; });
    await tester.tap(find.byKey(const ValueKey('lan-approve')));
    expect(decisions, 0);
  });
  testWidgets('accept sends exactly one decision and waits for backend', (tester) async {
    final decisions = <bool>[];
    await show(tester, decide: (value) async { decisions.add(value); return ''; });
    await tester.tap(find.byKey(const ValueKey('lan-approve'))); await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lan-approve'))); await tester.pump();
    expect(decisions, [true]);
  });
  testWidgets('deny stays distinct; transport error never implies authorization', (tester) async {
    final decisions = <bool>[];
    await show(tester, decide: (value) async { decisions.add(value); return 'channel closed'; });
    await tester.tap(find.byKey(const ValueKey('lan-deny'))); await tester.pump();
    expect(decisions, [false]); expect(find.text('channel closed'), findsOneWidget);
  });
}
