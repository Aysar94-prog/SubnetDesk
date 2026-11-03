import 'dart:convert';
import 'package:flutter/material.dart';
import '../../common.dart';
import '../../models/platform_model.dart';

class LanUnattendedAccess extends StatefulWidget {
  const LanUnattendedAccess({super.key, this.readState, this.save, this.translateText});
  final Future<String> Function()? readState;
  final Future<String> Function(bool, String)? save;
  final String Function(String)? translateText;
  @override
  State<LanUnattendedAccess> createState() => _LanUnattendedAccessState();
}

class _LanUnattendedAccessState extends State<LanUnattendedAccess> {
  final _password = TextEditingController();
  bool _enabled = false;
  bool _configured = false;
  bool _loading = true;
  bool _busy = false;
  String _error = '';
  String t(String text) => widget.translateText?.call(text) ?? translate(text);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final info = jsonDecode(await (widget.readState?.call() ?? bind.mainGetLanServerInfo())) as Map<String, dynamic>;
      if (mounted) setState(() {
        _enabled = info['password_access_enabled'] == true;
        _configured = info['configured'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to read unattended access settings'; });
    }
  }
  Future<void> _save() async {
    if (_enabled && !_configured && _password.text.isEmpty) {
      setState(() => _error = 'Set an unattended access password before enabling password access');
      return;
    }
    setState(() { _busy = true; _error = ''; });
    try {
      final result = await (widget.save?.call(_enabled, _password.text)
        ?? bind.mainSetUnattendedAccess(enabled: _enabled, password: _password.text));
      _password.clear();
      if (mounted) setState(() => _error = result);
      await _load();
    } catch (_) {
      _password.clear();
      if (mounted) setState(() => _error = 'Unable to save unattended access settings');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _password.clear(); _password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
      title: Text(t('Enable password access')), value: _enabled,
      onChanged: _loading || _busy ? null : (value) => setState(() => _enabled = value == true)),
    TextField(key: const ValueKey('unattended-password'), controller: _password,
      enabled: !_loading && !_busy, obscureText: true, autocorrect: false, enableSuggestions: false,
      decoration: InputDecoration(labelText: t('Password'), helperText: t(_configured
        ? 'Leave blank to keep current password' : 'Set a password for unattended access'))),
    const SizedBox(height: 8),
    Text(t('Temporary code and manual approval are independent of password access.')),
    OutlinedButton(key: const ValueKey('save-unattended'), onPressed: _loading || _busy ? null : _save,
      child: Text(t('Save'))),
    if (_error.isNotEmpty) Text(t(_error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
  ]);
}
