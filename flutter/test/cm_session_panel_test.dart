import 'package:flutter/material.dart';
import 'package:flutter_hbb/desktop/widgets/cm_session_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native ringtone failure is displayed in the dock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: CmSessionPanel(
              title: 'Phone',
              collapsed: false,
              showChat: true,
              chatLabel: 'Chat',
              controlsLabel: 'Controls',
              foldLabel: 'Fold',
              sessionPicker: const SizedBox.shrink(),
              chat: const Text('Chat'),
              controls: const Text('Controls'),
              onFold: () {},
              onShowChat: () {},
              onShowControls: () {},
              voiceRingError: 'Ringtone playback failed.',
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('cm-voice-ring-error')), findsOneWidget);
    expect(find.text('Ringtone playback failed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> mount(WidgetTester tester, {int unread = 0}) async {
    await tester.pumpWidget(MaterialApp(home: _PanelHost(unread: unread)));
  }

  testWidgets('incoming panel starts expanded with chat and stays visible', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byKey(const ValueKey('draft')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('draft')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folding leaves a short visible header and expands again', (
    tester,
  ) async {
    await mount(tester, unread: 2);
    await tester.tap(find.byKey(const ValueKey('cm-fold')));
    await tester.pump();
    expect(find.text('Phone'), findsOneWidget);
    expect(find.byKey(const ValueKey('cm-unread-count')), findsOneWidget);
    expect(find.byKey(const ValueKey('draft')), findsNothing);
    expect(tester.getSize(find.byType(CmSessionPanel)).height, 44);
    await tester.tap(find.byKey(const ValueKey('cm-fold')));
    await tester.pump();
    expect(tester.getSize(find.byType(CmSessionPanel)).height, 600);
    expect(find.byKey(const ValueKey('draft')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching controls preserves the chat draft', (tester) async {
    await mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('draft')),
      'unsent message',
    );
    await tester.tap(find.byKey(const ValueKey('cm-controls-tab')));
    await tester.pump();
    expect(find.text('Disconnect'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cm-chat-tab')));
    await tester.pump();
    expect(find.text('unsent message'), findsOneWidget);
  });

  testWidgets('folding preserves the model-owned draft', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(const ValueKey('draft')), 'keep draft');
    await tester.tap(find.byKey(const ValueKey('cm-fold')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cm-fold')));
    await tester.pump();
    expect(find.text('keep draft'), findsOneWidget);
  });

  testWidgets('chat input accepts keyboard text after reopening', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('cm-fold')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cm-fold')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('draft')));
    await tester.enterText(find.byKey(const ValueKey('draft')), 'hello phone');
    expect(find.text('hello phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PanelHost extends StatefulWidget {
  const _PanelHost({required this.unread});
  final int unread;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  bool collapsed = false;
  bool showChat = true;
  final draft = TextEditingController();

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: 360,
        height: collapsed ? 44 : 600,
        child: CmSessionPanel(
          title: 'Phone',
          collapsed: collapsed,
          showChat: showChat,
          chatLabel: 'Chat',
          controlsLabel: 'Permissions',
          foldLabel: 'Fold',
          unreadCount: widget.unread,
          sessionPicker: const SizedBox.shrink(),
          chat: TextField(key: const ValueKey('draft'), controller: draft),
          controls: const Text('Disconnect'),
          onFold: () => setState(() => collapsed = !collapsed),
          onShowChat: () => setState(() => showChat = true),
          onShowControls: () => setState(() => showChat = false),
        ),
      ),
    ),
  );
}
