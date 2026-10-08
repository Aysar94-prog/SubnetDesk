import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/models/incoming_voice_ring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only an authorized connected pending request rings', () {
    expect(
      IncomingVoiceRing.shouldRing(
        authorized: true,
        connected: true,
        incoming: true,
        inCall: false,
      ),
      true,
    );
    expect(
      IncomingVoiceRing.shouldRing(
        authorized: false,
        connected: true,
        incoming: true,
        inCall: false,
      ),
      false,
    );
    expect(
      IncomingVoiceRing.shouldRing(
        authorized: true,
        connected: false,
        incoming: true,
        inCall: false,
      ),
      false,
    );
    expect(
      IncomingVoiceRing.shouldRing(
        authorized: true,
        connected: true,
        incoming: false,
        inCall: false,
      ),
      false,
    );
    expect(
      IncomingVoiceRing.shouldRing(
        authorized: true,
        connected: true,
        incoming: true,
        inCall: true,
      ),
      false,
    );
  });
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
      expect(sounds, 1); // Unmuting a pending call rings immediately.
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 2);
      ring.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 2);
    },
  );

  testWidgets('snapshot recovers missed event and removes stale requests', (
    tester,
  ) async {
    var sounds = 0, stops = 0, now = 0;
    final ring = IncomingVoiceRing(
      now: () => now,
      playSound: () async {
        sounds++;
      },
      stopSound: () async {
        stops++;
      },
    );
    ring.synchronize([1, 2, -1, 0]);
    expect(sounds, 1);
    ring.synchronize([2]);
    expect(stops, 0);
    now = 30000;
    await tester.pump(const Duration(seconds: 30));
    expect(stops, 1);
    ring.synchronize([2]);
    expect(sounds, 1); // Duplicate snapshot cannot restart a timed-out request.
    ring.synchronize([]);
    ring.synchronize([2]); // A genuine new request can ring again.
    expect(sounds, 2);
    ring.dispose();
    expect(stops, 2);
  });

  testWidgets('mute, last cancellation and disposal stop actual audio', (
    tester,
  ) async {
    var stops = 0;
    final ring = IncomingVoiceRing(
      playSound: () async {},
      stopSound: () async {
        stops++;
      },
    );
    ring.update(1, incoming: true);
    ring.toggleMuted();
    expect(stops, 1);
    ring.toggleMuted();
    ring.update(1, incoming: false);
    expect(stops, 2);
    ring.update(2, incoming: true);
    ring.dispose();
    expect(stops, 3);
    await tester.pump(const Duration(seconds: 3));
    expect(stops, 3);
  });

  testWidgets('production channel calls app ringtone, not SystemSound', (
    tester,
  ) async {
    final methods = <String>[];
    const channel = MethodChannel('subnetdesk/audio');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final ring = IncomingVoiceRing();
    ring.update(1, incoming: true);
    await tester.pump();
    ring.update(1, incoming: false);
    await tester.pump();
    expect(methods, ['playVoiceRing', 'stopVoiceRing']);
    ring.dispose();
  });

  testWidgets('playback error is visible and cleared by successful retry', (
    tester,
  ) async {
    var fail = true;
    final ring = IncomingVoiceRing(
      playSound: () async {
        if (fail) throw PlatformException(code: 'audio-playback');
      },
    );
    ring.update(1, incoming: true);
    await tester.pump();
    expect(ring.playbackError, isNotNull);
    fail = false;
    await tester.pump(const Duration(seconds: 3));
    expect(ring.playbackError, isNull);
    ring.dispose();
  });

  testWidgets('late playback error after dispose cannot notify dead model', (
    tester,
  ) async {
    final pending = Completer<void>();
    final ring = IncomingVoiceRing(playSound: () => pending.future);
    ring.update(1, incoming: true);
    ring.dispose();
    pending.completeError(PlatformException(code: 'late-audio-error'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'local answer/reject stays silent through stale pending snapshots',
    (tester) async {
      var sounds = 0, stops = 0;
      final ring = IncomingVoiceRing(
        playSound: () async {
          sounds++;
        },
        stopSound: () async {
          stops++;
        },
      );
      ring.synchronize([1]);
      ring.silence(1);
      ring.synchronize([1]);
      await tester.pump(const Duration(seconds: 3));
      expect(sounds, 1);
      expect(stops, 1);
      ring.synchronize([]);
      ring.synchronize([1]);
      expect(sounds, 2);
      ring.dispose();
    },
  );
}
