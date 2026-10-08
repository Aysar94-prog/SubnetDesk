import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One shared, bounded output alert for pending calls; never answers a call.
class IncomingVoiceRing extends ChangeNotifier {
  IncomingVoiceRing({
    int Function()? now,
    Future<void> Function()? playSound,
    Future<void> Function()? stopSound,
  }) {
    final clock = Stopwatch()..start();
    _now = now ?? () => clock.elapsedMilliseconds;
    _playSound = playSound ?? () => _audio.invokeMethod<void>('playVoiceRing');
    _stopSound =
        stopSound ??
        (playSound != null
            ? () async {}
            : () => _audio.invokeMethod<void>('stopVoiceRing'));
  }
  static const _audio = MethodChannel('subnetdesk/audio');
  late final int Function() _now;
  late final Future<void> Function() _playSound;
  late final Future<void> Function() _stopSound;
  final Set<int> _incoming = {};
  final Map<int, int> _expires = {};
  Timer? _timer;
  bool muted = false;
  String? playbackError;
  bool _soundRequested = false;
  bool _disposed = false;
  int _generation = 0;

  static bool shouldRing({
    required bool authorized,
    required bool connected,
    required bool incoming,
    required bool inCall,
  }) => authorized && connected && incoming && !inCall;

  void toggleMuted() {
    muted = !muted;
    if (muted)
      _stopPlayback();
    else if (_expires.isNotEmpty)
      _tick();
    notifyListeners();
  }

  /// Authoritative snapshots recover a request arriving before client creation.
  /// Retained IDs deliberately do not reset an expired 30-second alert.
  void synchronize(Iterable<int> pendingIds) {
    final pending = pendingIds.where((id) => id > 0).toSet();
    for (final id in _incoming.difference(pending)) {
      update(id, incoming: false);
    }
    for (final id in pending) {
      update(id, incoming: true);
    }
  }

  /// A local answer/reject must stay silent while its native reply is in flight.
  /// Keep the ID until native state clears it, like the timeout tombstone.
  void silence(int id) {
    if (id <= 0) return;
    _incoming.add(id);
    _expires.remove(id);
    if (_expires.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _stopPlayback();
    }
  }

  void update(int id, {required bool incoming}) {
    if (!incoming) {
      _incoming.remove(id);
      _expires.remove(id);
      if (_expires.isEmpty) {
        _timer?.cancel();
        _timer = null;
        _stopPlayback();
      }
      return;
    }
    if (id <= 0 || !_incoming.add(id)) return;
    _expires[id] = _now() + 30000;
    if (_timer != null) return;
    _tick();
    if (_expires.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
    }
  }

  void _tick() {
    final now = _now();
    _expires.removeWhere((_, expires) => now >= expires);
    if (_expires.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _stopPlayback();
      return;
    }
    if (!muted) {
      _soundRequested = true;
      final generation = ++_generation;
      _playSound().then((_) {
        if (_disposed || generation != _generation) return;
        debugPrint('Incoming voice ring: app playback started');
        if (playbackError != null) {
          playbackError = null;
          notifyListeners();
        }
      }, onError: (Object error) => _playbackFailed(error, generation));
    }
  }

  void _playbackFailed(Object error, int generation) {
    debugPrint('Incoming voice ring failed: $error');
    if (_disposed || generation != _generation) return;
    playbackError = 'Ringtone playback failed. Check the audio output.';
    notifyListeners();
  }

  void _stopPlayback() {
    if (!_soundRequested) return;
    _soundRequested = false;
    final generation = ++_generation;
    _stopSound().catchError(
      (Object error) => _playbackFailed(error, generation),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposed = true;
    _stopPlayback();
    super.dispose();
  }
}
