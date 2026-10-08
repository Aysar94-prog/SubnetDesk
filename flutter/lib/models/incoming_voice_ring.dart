import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One shared, bounded output alert for pending calls; never answers a call.
class IncomingVoiceRing extends ChangeNotifier {
  IncomingVoiceRing({int Function()? now, Future<void> Function()? playSound}) {
    final clock = Stopwatch()..start();
    _now = now ?? () => clock.elapsedMilliseconds;
    _playSound = playSound ?? () => SystemSound.play(SystemSoundType.alert);
  }
  late final int Function() _now;
  late final Future<void> Function() _playSound;
  final Set<int> _incoming = {};
  final Map<int, int> _expires = {};
  Timer? _timer;
  bool muted = false;

  void toggleMuted() {
    muted = !muted;
    notifyListeners();
  }

  void update(int id, {required bool incoming}) {
    if (!incoming) {
      _incoming.remove(id);
      _expires.remove(id);
      if (_expires.isEmpty) {
        _timer?.cancel();
        _timer = null;
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
      return;
    }
    if (!muted) {
      _playSound().catchError((Object error) {
        debugPrint('Incoming voice ring failed: $error');
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
