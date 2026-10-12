import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Only app-owned copies returned by the Android share receiver are queued.
class SharedFileInbox extends ChangeNotifier {
  static final instance = SharedFileInbox();
  static const _channel = MethodChannel('subnetdesk/share');
  List<String> files = [];
  String? error;
  bool _initialized = false;
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
    refresh();
  }

  Future<void> refresh() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('pending');
      files = List<String>.from(data?['files'] ?? const []);
      final errors = List<String>.from(data?['errors'] ?? const []);
      error = errors.isEmpty ? null : errors.join('\n');
    } catch (e) {
      error = 'Unable to load shared files. Please retry.';
      debugPrint('Shared file inbox: $e');
    }
    notifyListeners();
  }

  Future<void> acknowledge(List<String> sent) async {
    try {
      await _channel.invokeMethod<void>('acknowledge', sent);
      error = null;
      await refresh();
    } catch (e) {
      error = 'Unable to update shared files. Please retry.';
      debugPrint('Shared file acknowledgement: $e');
      notifyListeners();
    }
  }
}
