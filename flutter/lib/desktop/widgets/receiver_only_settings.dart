import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class ReceiverOnlySettings extends StatefulWidget {
  const ReceiverOnlySettings({
    super.key,
    required this.initiallyLocked,
    required this.readOption,
    required this.writeOption,
  });
  final bool initiallyLocked;
  final Future<String> Function(String) readOption;
  final Future<void> Function(String, String) writeOption;
  @override
  State<ReceiverOnlySettings> createState() => _ReceiverOnlySettingsState();
}

class _ReceiverOnlySettingsState extends State<ReceiverOnlySettings> {
  final _lock = TextEditingController();
  final _unlock = TextEditingController();
  late bool _locked = widget.initiallyLocked;
  bool _busy = false;
  bool? _managed;
  Timer? _policyTimer;
  String _status = '';
  static const _defaultHash =
      'b008f337c227dcb4fa0fa4b1e9b915dd24a34e698b6739236f96b29fa9d2f532';

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPolicy());
    _policyTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshPolicy(),
    );
  }

  Future<void> _refreshPolicy() async {
    if (_busy) return;
    try {
      final managed =
          await widget.readOption('incoming-only-scope') == 'device';
      final mode = managed
          ? await widget.readOption('incoming-only') == 'Y'
          : _locked;
      if (mounted && !_busy && (managed != _managed || mode != _locked))
        setState(() {
          _managed = managed;
          _locked = mode;
        });
    } catch (_) {
      if (mounted && _managed == null)
        setState(() => _status = 'Could not read receiver policy.');
    }
  }

  @override
  void dispose() {
    _policyTimer?.cancel();
    _lock.dispose();
    _unlock.dispose();
    super.dispose();
  }

  Future<void> _change(bool lock) async {
    if (await widget.readOption('incoming-only-scope') == 'device') {
      await _refreshPolicy();
      return;
    }
    final password = lock ? _lock.text : _unlock.text;
    if (password.isEmpty) {
      setState(() => _status = 'Enter a password.');
      return;
    }
    setState(() => _busy = true);
    try {
      final hash = sha256.convert(utf8.encode(password)).toString();
      if (!lock) {
        final stored = await widget.readOption('incoming-only-password');
        if (hash != (stored.isEmpty ? _defaultHash : stored)) {
          if (mounted) setState(() => _status = 'Incorrect unlock password.');
          return;
        }
      }
      await widget.writeOption('incoming-only', lock ? 'Y' : '');
      await widget.writeOption('incoming-only-password', lock ? hash : '');
      await widget.writeOption(
        'incoming-only-initialized',
        lock ? 'locked' : 'unlocked',
      );
      if (mounted) {
        setState(() {
          _locked = lock;
          _status =
              'Receiver-only mode ${lock ? 'locked' : 'unlocked'}. Restart SubnetDesk to update the layout.';
          _lock.clear();
          _unlock.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Could not save receiver-only settings.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_managed == null)
        Text(_status.isEmpty ? 'Loading receiver policy…' : _status)
      else if (_managed == true) ...[
        const Text(
          'Receiver policy is managed by SubnetDesk Deploy for this device and all Windows accounts.',
        ),
        Text(
          _locked
              ? 'Device policy: receiver-only.'
              : 'Device policy: send-and-receive.',
        ),
        const Text(
          'Change the policy or its unlock password from Deploy. Local account settings cannot override it.',
        ),
      ] else ...[
        Text(
          _locked
              ? 'This device is currently receiver-only.'
              : 'This device can both send and receive.',
        ),
        TextField(
          controller: _lock,
          enabled: !_busy,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Lock password'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : () => _change(true),
          child: const Text('Lock as receiver-only'),
        ),
        TextField(
          controller: _unlock,
          enabled: !_busy,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Unlock password'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : () => _change(false),
          child: const Text('Unlock'),
        ),
        if (_status.isNotEmpty) Text(_status),
      ],
    ],
  );
}
