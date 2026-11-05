import 'dart:convert';

import 'package:flutter/material.dart';
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
    this.hasSavedPassword,
    this.onSubmit,
    this.onCancel,
  });
  final String endpoint;
  final bool editEndpoint;
  final String Function(String) translateText;
  final String title;
  final bool allowSavedPassword;
  final bool Function(String endpoint)? hasSavedPassword;
  final Future<String> Function(WindowsLanAccessSelection)? onSubmit;
  final VoidCallback? onCancel;
  @override
  State<WindowsLanAccessDialog> createState() => _WindowsLanAccessDialogState();
}

class _WindowsLanAccessDialogState extends State<WindowsLanAccessDialog> {
  late final TextEditingController _endpoint;
  final _password = TextEditingController();
  bool _useSaved = false;
  bool _remember = false;
  String _error = '';
  bool _busy = false;
  String t(String text) => widget.translateText(text);

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController(text: widget.endpoint);
    _refreshSaved();
  }

  void _refreshSaved() {
    _useSaved = widget.allowSavedPassword &&
        (widget.hasSavedPassword?.call(_endpoint.text.trim()) ?? false);
    _remember = _useSaved;
  }

  void _clearCredentials() {
    _password.clear();
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

    final entered = _password.text;
    final String? payload;
    if (_useSaved && entered.isEmpty) {
      payload = null; // Native code loads the fingerprint-bound secret.
    } else if (entered.isEmpty) {
      payload = jsonEncode({'lan_version': 1, 'access_method': 2,
        'temporary_code': ''});
    } else {
      payload = jsonEncode({'lan_version': 1, 'username': '',
        'password': entered, 'remember': widget.allowSavedPassword && _remember,
        'auto_access': true});
    }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t(widget.title)),
    content: SizedBox(
      width: (MediaQuery.sizeOf(context).width - 128)
          .clamp(0.0, 440.0)
          .toDouble(),
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
                onChanged: (_) => setState(() {
                  _clearCredentials();
                  _refreshSaved();
                }),
                onSubmitted: (_) => _submit(),
              )
            else
              Text(widget.endpoint),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('windows-lan-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: t('Password or temporary code'),
                hintText: _useSaved ? '********' : null,
                helperText: t(_useSaved
                    ? 'Saved password will be used'
                    : 'Leave empty to request manual approval'),
                suffixIcon: _useSaved ? IconButton(
                  tooltip: t('Use another password or manual approval'),
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() { _useSaved = false; _remember = false; }),
                ) : null,
              ),
              onChanged: (value) => setState(() { _useSaved = false; }),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.allowSavedPassword)
              CheckboxListTile(
                key: const ValueKey('windows-lan-remember'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t('Remember password')),
                value: _remember,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _remember = value == true),
              ),
            if (_error.isNotEmpty)
              Text(
                t(_error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => showConnectionDiagnostic(
                      context, _endpoint.text, translateText: t),
              icon: const Icon(Icons.network_check),
              label: Text(t('Check connection')),
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
