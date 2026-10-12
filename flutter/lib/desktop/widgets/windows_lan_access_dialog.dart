import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/widgets/connection_diagnostic_dialog.dart';

class WindowsLanAccessSelection {
  const WindowsLanAccessSelection(this.endpoint, this.payload);
  final String endpoint;
  final String? payload;
}

/// Existing LAN wire methods; choosing manual sends a request, never a grant.
class WindowsLanAccessDialog extends StatefulWidget {
  const WindowsLanAccessDialog({
    super.key,
    required this.endpoint,
    this.editEndpoint = false,
    required this.translateText,
    this.title = 'Connect',
    this.allowSavedPassword = true,
    this.onSubmit,
    this.onCancel,
  });
  final String endpoint;
  final bool editEndpoint;
  final String Function(String) translateText;
  final String title;
  final bool allowSavedPassword;
  final Future<String> Function(WindowsLanAccessSelection)? onSubmit;
  final VoidCallback? onCancel;
  @override
  State<WindowsLanAccessDialog> createState() => _WindowsLanAccessDialogState();
}

class _WindowsLanAccessDialogState extends State<WindowsLanAccessDialog> {
  late final TextEditingController _endpoint;
  final _password = TextEditingController();
  final _code = TextEditingController();
  int _method = 0;
  bool _remember = false;
  String _error = '';
  bool _busy = false;
  String t(String text) => widget.translateText(text);
  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController(text: widget.endpoint);
  }

  void _clearCredentials() {
    _password.clear();
    _code.clear();
    _remember = false;
    _error = '';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final endpoint = _endpoint.text.trim();
    if (endpoint.isEmpty) {
      setState(() => _error = 'Enter the receiver IP address or hostname');
      return;
    }
    final code = _code.text.trim();
    if (_method == 1 && !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter a 6-digit temporary code');
      return;
    }
    if (_method == 0 && _password.text.isEmpty && !widget.allowSavedPassword) {
      setState(
        () => _error =
            'Enter the receiver password or choose another access method',
      );
      return;
    }
    final payload = _method != 0
        ? jsonEncode({
            'lan_version': 1,
            'access_method': _method,
            'temporary_code': _method == 1 ? code : '',
          })
        : _password.text.isEmpty
        ? null
        : jsonEncode({
            'lan_version': 1,
            'username': '',
            'password': _password.text,
            'remember': _remember,
          });
    _clearCredentials();
    final selection = WindowsLanAccessSelection(endpoint, payload);
    if (widget.onSubmit == null) {
      Navigator.of(context).pop(selection);
      return;
    }
    setState(() => _busy = true);
    String error;
    try {
      error = await widget.onSubmit!(selection);
    } catch (_) {
      error = 'Unable to submit file transfer access. Please retry.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _clearCredentials();
    _endpoint.clear();
    _endpoint.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t(widget.title)),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.editEndpoint)
              TextField(
                key: const ValueKey('windows-lan-endpoint'),
                controller: _endpoint,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: '${t('Local Address')} (IP / DNS)',
                ),
                onChanged: (_) => setState(_clearCredentials),
                onSubmitted: (_) => _submit(),
              )
            else
              Text(widget.endpoint),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('windows-lan-method'),
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(labelText: t('Access method')),
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(
                    t('Password / saved password'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(value: 1, child: Text(t('Temporary code'))),
                DropdownMenuItem(value: 2, child: Text(t('Manual approval'))),
              ],
              onChanged: _busy
                  ? null
                  : (method) => setState(() {
                      _clearCredentials();
                      _method = method ?? 0;
                    }),
            ),
            const SizedBox(height: 12),
            if (_method == 0) ...[
              TextField(
                key: const ValueKey('windows-lan-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: t('Password'),
                  helperText: t(
                    widget.allowSavedPassword
                        ? 'Leave blank to use the saved password for this device'
                        : 'Enter the unattended access password configured on the receiver',
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t('Remember password')),
                value: _remember,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _remember = value == true),
              ),
            ],
            if (_method == 1)
              TextField(
                key: const ValueKey('windows-lan-code'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: t('Receiver code (6 digits)'),
                ),
                onSubmitted: (_) => _submit(),
              ),
            if (_method == 2)
              Text(
                t(
                  'A request appears on the receiver. Control starts only after acceptance.',
                ),
              ),
            if (_error.isNotEmpty)
              Text(
                t(_error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextButton.icon(
              onPressed: _busy ? null : () => showConnectionDiagnostic(context, _endpoint.text, translateText: t),
              icon: const Icon(Icons.network_check), label: Text(t('Check connection')),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('windows-lan-cancel'),
        onPressed: _busy
            ? null
            : () {
                _clearCredentials();
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else {
                  Navigator.of(context).pop();
                }
              },
        child: Text(t('Cancel')),
      ),
      ElevatedButton(
        key: const ValueKey('windows-lan-connect'),
        onPressed: _busy ? null : _submit,
        child: Text(t('Connect')),
      ),
    ],
  );
}
