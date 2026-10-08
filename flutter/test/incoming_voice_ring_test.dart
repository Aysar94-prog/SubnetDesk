import 'package:flutter_hbb/models/incoming_voice_ring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'rings once on transition, not every state sync, then every 3 seconds',
    (tester) async {
      var now = 0, sounds = 0;
      final ring = IncomingVoiceRing(
        now: () => now,
        playSound: () async {
          sounds++;
        },
      );
      ring.update(1, incoming: true);
      for (var i = 0; i < 10; i++) {
        ring.update(1, incoming: true);
      }
      expect(sounds, 1);
      now = 3000;
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 2);
      ring.update(1, incoming: false);
      now = 6000;
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 2);
      ring.dispose();
    },
  );
  testWidgets(
    'times out after 30 seconds and duplicate sync cannot restart it',
    (tester) async {
      var now = 0, sounds = 0;
      final ring = IncomingVoiceRing(
        now: () => now,
        playSound: () async {
          sounds++;
        },
      );
      ring.update(1, incoming: true);
      now = 30000;
      await tester.pump(const Duration(seconds: 30));
      ring.update(1, incoming: true);
      expect(sounds, 1);
      ring.dispose();
    },
  );
  testWidgets(
    'multiple calls share one sound timer; removing last pending call stops',
    (tester) async {
      var sounds = 0;
      final ring = IncomingVoiceRing(
        playSound: () async {
          sounds++;
        },
      );
      ring.update(1, incoming: true);
      ring.update(2, incoming: true);
      expect(sounds, 1);
      ring.update(1, incoming: false);
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 2);
      ring.update(2, incoming: false);
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 2);
      ring.dispose();
    },
  );
  testWidgets(
    'mute is independent and dispose cancels active playback schedule',
    (tester) async {
      var sounds = 0;
      final ring = IncomingVoiceRing(
        playSound: () async {
          sounds++;
        },
      );
      ring.toggleMuted();
      ring.update(1, incoming: true);
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 0);
      ring.toggleMuted();
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 1);
      ring.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 1);
    },
  );
}
