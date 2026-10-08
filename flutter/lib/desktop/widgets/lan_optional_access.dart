import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/platform_model.dart';

/// Local, volatile receiver controls. No code is persisted by Flutter.
class LanOptionalAccess extends StatefulWidget {
  const LanOptionalAccess({super.key, this.readState, this.setMethods, this.generateCode});
  final Future<String> Function()? readState;
  final Future<String> Function(bool code, bool manual)? setMethods;
  final Future<String> Function()? generateCode;
  @override
  State<LanOptionalAccess> createState() => _LanOptionalAccessState();
}
class _LanOptionalAccessState extends State<LanOptionalAccess> {
  Timer? _timer;
  Map<String, dynamic> _state = {};
  bool _busy = false;
  bool _reading = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }
  Future<void> _refresh() async {
    if (_reading) return;
    _reading = true;
    try {
      final state = jsonDecode(await (widget.readState?.call() ?? bind.mainGetLanOptionalAccess())) as Map<String, dynamic>;
      if (mounted) setState(() => _state = state);
    } catch (_) {
      if (mounted) setState(() { _state = {}; _error = 'تعذر قراءة حالة طرق الدخول'; });
    } finally { _reading = false; }
  }
  Future<void> _change(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final error = await action();
      if (mounted) setState(() => _error = error);
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'لم يُطبّق التغيير');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<String> _set(bool code, bool manual) => widget.setMethods?.call(code, manual)
      ?? bind.mainSetLanOptionalAccess(code: code, manual: manual);
  Future<String> _generate() => widget.generateCode?.call() ?? bind.mainRegenerateLanCode();
  @override
  void dispose() { _timer?.cancel(); _state.clear(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final available = _state['available'] == true;
    final codeEnabled = _state['code_enabled'] == true;
    final manualEnabled = _state['manual_enabled'] == true;
    final code = _state['code']?.toString() ?? '';
    return Padding(padding: const EdgeInsets.all(10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('طرق الدخول الإضافية'),
        const Text('كلمة المرور تبقى متاحة. الخيارات التالية تُغلق عند إعادة تشغيل البرنامج.', style: TextStyle(fontSize: 11)),
        if (!available) const Text('متاحة فقط عندما تكون هذه النسخة مستقبِلة والشاشة غير مقفلة.', style: TextStyle(fontSize: 11)),
        CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('كود مؤقت'), value: codeEnabled,
          onChanged: _busy || (!available && !codeEnabled) ? null : (value) => _change(() =>
            _set(value == true, manualEnabled))),
        if (available && codeEnabled) ...[
          if (code.isNotEmpty) Text('$code · ${_state['expires_seconds']} ثانية',
            key: const ValueKey('lan-temporary-code'), style: const TextStyle(fontSize: 20)),
          if (code.isEmpty) const Text('لا يوجد كود صالح. أنشئ كودًا جديدًا.'),
          OutlinedButton(onPressed: _busy ? null : () => _change(_generate),
            child: const Text('إنشاء كود / استبداله')),
          const Text('6 أرقام · دقيقتان · استخدام واحد', style: TextStyle(fontSize: 11)),
        ],
        CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('الموافقة اليدوية'), value: manualEnabled,
          onChanged: _busy || (!available && !manualEnabled) ? null : (value) => _change(() =>
            _set(codeEnabled, value == true))),
        if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]));
  }
}
