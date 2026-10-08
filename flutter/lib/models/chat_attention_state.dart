import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Session-only attention state, using a monotonic clock and bounded alert window.
class ChatAttentionState extends ChangeNotifier {
  ChatAttentionState({
    int Function()? now,
    Future<void> Function()? playSound,
  }) {
    final clock = Stopwatch()..start();
    _now = now ?? () => clock.elapsedMilliseconds;
    _playSound = playSound ?? () => SystemSound.play(SystemSoundType.alert);
  }

  late final int Function() _now;
  late final Future<void> Function() _playSound;
  final Map<int, int> _lastReceived = {};
  final List<int> _window = [];
  Timer? _clearTimer;
  int? attentionSessionId;
  bool muted = false;

  void toggleMuted() {
    muted = !muted;
    notifyListeners();
  }

  bool receive(int id, {required bool authorized, required bool connected}) {
    if (!authorized || !connected || id <= 0) return false;
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
      notifyListeners();
    });
    notifyListeners();
    if (!muted) {
      _playSound().catchError((Object error) {
        debugPrint('Chat attention sound failed: $error');
      });
    }
    return true;
  }

  void removeSession(int id) {
    _lastReceived.remove(id);
    if (attentionSessionId == id) {
      attentionSessionId = null;
      _clearTimer?.cancel();
      notifyListeners();
    }
    // Do not clear the aggregate window: reconnect must not bypass it.
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}
