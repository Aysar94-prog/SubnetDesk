import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/widgets/buzzer_button.dart';
import 'package:flutter_hbb/desktop/widgets/cm_session_panel.dart';
import 'package:flutter_hbb/models/chat_attention_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only authenticated live sessions can buzz', (tester) async {
    var sounds = 0;
    final state = ChatAttentionState(
      playSound: () async {
        sounds++;
      },
    );
    addTearDown(state.dispose);
    expect(state.receive(1, authorized: false, connected: true), false);
    expect(state.receive(1, authorized: true, connected: false), false);
    expect(state.receive(0, authorized: true, connected: true), false);
    expect(sounds, 0);
    expect(state.attentionSessionId, null);
  });
  testWidgets('cooldown and aggregate cap are enforced on receiver', (
    tester,
  ) async {
    var now = 0;
    var sounds = 0;
    final state = ChatAttentionState(
      now: () => now,
      playSound: () async {
        sounds++;
      },
    );
    addTearDown(state.dispose);
    bool buzz(int id) => state.receive(id, authorized: true, connected: true);
    expect(buzz(1), true);
    now = 4999;
    expect(buzz(1), false);
    now = 5000;
    expect(buzz(1), true);
    expect(buzz(2), true);
    expect(buzz(3), false);
    now = 10000;
    expect(buzz(3), true);
    expect(sounds, 4);
    await tester.pump(const Duration(seconds: 6));
  });
  testWidgets('muting preserves visible indication and does not play sound', (
    tester,
  ) async {
    var sounds = 0;
    final state = ChatAttentionState(
      playSound: () async {
        sounds++;
      },
    );
    addTearDown(state.dispose);
    state.toggleMuted();
    expect(state.receive(1, authorized: true, connected: true), true);
    expect(state.attentionSessionId, 1);
    expect(sounds, 0);
    await tester.pump(const Duration(seconds: 6));
    expect(state.attentionSessionId, null);
  });
  testWidgets(
    'removal clears badge and per-session state but retains global cap',
    (tester) async {
      final state = ChatAttentionState(now: () => 0, playSound: () async {});
      addTearDown(state.dispose);
      for (var id = 1; id <= 3; id++) {
        expect(state.receive(id, authorized: true, connected: true), true);
        state.removeSession(id);
      }
      expect(state.attentionSessionId, null);
      expect(state.receive(4, authorized: true, connected: true), false);
    },
  );
  testWidgets(
    'playback failure leaves visible attention and no unhandled error',
    (tester) async {
      final state = ChatAttentionState(
        playSound: () async {
          throw PlatformException(code: 'no-output');
        },
      );
      addTearDown(state.dispose);
      expect(state.receive(1, authorized: true, connected: true), true);
      await tester.pump();
      expect(state.attentionSessionId, 1);
      expect(tester.takeException(), null);
      await tester.pump(const Duration(seconds: 6));
    },
  );
  testWidgets('default player requests desktop system alert', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final state = ChatAttentionState();
    addTearDown(state.dispose);
    state.receive(1, authorized: true, connected: true);
    await tester.pump();
    expect(calls.single.method, 'SystemSound.play');
    expect(calls.single.arguments, 'SystemSoundType.alert');
    await tester.pump(const Duration(seconds: 6));
  });
  testWidgets('buzzer button disables unsupported receivers and cooldown', (
    tester,
  ) async {
    var sends = 0;
    Future<void> mount(bool supported, bool cooldown) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuzzerButton(
            supported: supported,
            coolingDown: cooldown,
            onPressed: () {
              sends++;
            },
          ),
        ),
      ),
    );
    await mount(false, false);
    await tester.tap(find.byKey(const ValueKey('chat-buzzer')));
    expect(sends, 0);
    await mount(true, true);
    await tester.tap(find.byKey(const ValueKey('chat-buzzer')));
    expect(sends, 0);
    await mount(true, false);
    await tester.tap(find.byKey(const ValueKey('chat-buzzer')));
    expect(sends, 1);
  });
  testWidgets(
    'dock shows attention, mute action and keeps existing input focus',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var toggles = 0;
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
                controlsLabel: 'Permissions',
                foldLabel: 'Fold',
                attention: true,
                soundMuted: true,
                onToggleSound: () {
                  toggles++;
                },
                sessionPicker: const SizedBox.shrink(),
                chat: TextField(focusNode: focus),
                controls: const SizedBox.shrink(),
                onFold: () {},
                onShowChat: () {},
                onShowControls: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('cm-buzzer-attention')), findsOneWidget);
      expect(focus.hasFocus, false);
      await tester.tap(find.byKey(const ValueKey('cm-buzzer-mute')));
      expect(toggles, 1);
      expect(focus.hasFocus, false);
      expect(tester.takeException(), null);
    },
  );
}
