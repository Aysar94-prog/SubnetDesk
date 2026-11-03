import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../common.dart';
import '../../models/platform_model.dart';

/// Receiver-owned controls. Only the manual preference persists, never the code.
class LanOptionalAccess extends StatefulWidget {
  const LanOptionalAccess({super.key, this.readState, this.setMethods, this.generateCode,
    this.showSettings = false, this.translateText});
  final bool showSettings;
  final String Function(String)? translateText;
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
  String t(String text) => widget.translateText?.call(text) ?? translate(text);
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
      if (mounted) setState(() { _state = {}; _error = 'Unable to read access methods'; });
    } finally { _reading = false; }
  }
  Future<void> _change(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final error = await action();
      if (mounted) setState(() => _error = error);
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'The change could not be applied');
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
    final error = _error.isNotEmpty ? _error : (_state['manual_preference_error']?.toString() ?? '');
    return Padding(padding: const EdgeInsets.all(10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.showSettings) ...[
        Text(t('Temporary code'), key: const ValueKey('lan-code-heading')),
        if (!available) Text(t('Available only while this receiver is running and the screen is unlocked.'), style: const TextStyle(fontSize: 11)),
        if (available && codeEnabled) ...[
          if (code.isNotEmpty) SelectableText(code,
            key: const ValueKey('lan-temporary-code'), style: const TextStyle(fontSize: 26, letterSpacing: 3)),
          if (code.isNotEmpty) Text('${t('Expires in')} ${Duration(seconds: (_state['expires_seconds'] as num? ?? 0).toInt()).toString().split('.').first}',
            key: const ValueKey('lan-code-expiry'), style: const TextStyle(fontSize: 11)),
          if (code.isEmpty) Text(t((_state['retry_seconds'] as num? ?? 0) > 0
            ? 'Too many attempts. Please wait before using a new code.' : 'Preparing a new temporary code...')),
          OutlinedButton(onPressed: _busy ? null : () => _change(_generate),
            child: Text(t('New code'))),
          Text(t('6 digits · 2 hours · reusable until restart or expiry'), style: const TextStyle(fontSize: 11)),
        ],
        ],
        if (widget.showSettings) ...[
        Text(t('Manual approval')),
        Text(t('Enabled by default. Your choice is saved. Every request requires local acceptance.'), style: const TextStyle(fontSize: 11)),
        CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: Text(t('Enable manual approval')), value: manualEnabled,
          onChanged: _busy || (!available && !manualEnabled) ? null : (value) => _change(() =>
            _set(codeEnabled, value == true))),
        ],
        if (error.isNotEmpty) Text(t(error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]));
  }
}
