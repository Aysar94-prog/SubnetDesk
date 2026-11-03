import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Session-only attention state, using a monotonic clock and bounded alert window.
class ChatAttentionState extends ChangeNotifier {
  ChatAttentionState({
    int Function()? now,
    Future<void> Function()? playSound,
    Future<void> Function()? stopSound,
  }) {
    final clock = Stopwatch()..start();
    _now = now ?? () => clock.elapsedMilliseconds;
    _playSound = playSound ?? () async { await _audio.invokeMethod<bool>('playChatBuzzer'); };
    _stopSound = stopSound ?? (playSound != null ? () async {} :
        () => _audio.invokeMethod<void>('stopChatBuzzer'));
  }

  static const _audio = MethodChannel('subnetdesk/audio');
  late final int Function() _now;
  late final Future<void> Function() _playSound;
  late final Future<void> Function() _stopSound;
  final Map<int, int> _lastReceived = {};
  final List<int> _window = [];
  Timer? _clearTimer;
  int? attentionSessionId;
  bool muted = false;
  String? playbackError;
  bool _soundRequested = false;
  bool _disposed = false;
  int _generation = 0;

  void toggleMuted() {
    muted = !muted;
    if (muted) _stopPlayback();
    notifyListeners();
  }

  bool receive(int id, {required bool authorized, required bool connected}) {
    if (_disposed || !authorized || !connected || id <= 0) return false;
    final now = _now();
    final last = _lastReceived[id];
    if (last != null && now - last < 5000) return false;
    _window.removeWhere((time) => now - time >= 10000);
    if (_window.length >= 3) return false;
    _window.add(now);
    _lastReceived[id] = now;
    attentionSessionId = id;
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 6), () {
      attentionSessionId = null;
      _stopPlayback();
      notifyListeners();
    });
    notifyListeners();
    if (!muted) {
      _soundRequested = true;
      final generation = ++_generation;
      _playSound().then((_) {
        if (_disposed || generation != _generation) return;
        if (playbackError != null) {
          playbackError = null;
          notifyListeners();
        }
      }, onError: (Object error) => _playbackFailed(error, generation));
    }
    return true;
  }

  void removeSession(int id) {
    _lastReceived.remove(id);
    if (attentionSessionId == id) {
      attentionSessionId = null;
      _clearTimer?.cancel();
      _stopPlayback();
      notifyListeners();
    }
    // Do not clear the aggregate window: reconnect must not bypass it.
  }

  void _playbackFailed(Object error, int generation) {
    debugPrint('Chat attention sound failed: $error');
    if (_disposed || generation != _generation) return;
    playbackError = 'Buzzer playback failed. Check the audio output.';
    notifyListeners();
  }

  void _stopPlayback() {
    if (!_soundRequested) return;
    _soundRequested = false;
    final generation = ++_generation;
    _stopSound().catchError((Object error) => _playbackFailed(error, generation));
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _disposed = true;
    _stopPlayback();
    super.dispose();
  }
}
