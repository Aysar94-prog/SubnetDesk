import 'dart:convert';
import '../../models/platform_model.dart' show bind;
import 'package:flutter/material.dart';
import 'windows_lan_access_dialog.dart';

/// Keep the dialog on the persistent navigator, not a closing toolbar popup.
Future<void> requestWindowsFileTransferAccess(
  BuildContext context,
  String endpoint, {
  required String Function(String) translateText,
  bool Function(String endpoint)? hasSavedPassword,
  required Future<void> Function(WindowsLanAccessSelection) connect,
}) async {
  final stableContext = Navigator.of(context, rootNavigator: true).context;
  final selection = await showDialog<WindowsLanAccessSelection>(
    context: stableContext,
    builder: (_) => WindowsLanAccessDialog(
          hasSavedPassword: hasSavedPassword ?? (endpoint) => bind.mainHasLegacyLanCredential(fingerprint: endpoint),
      endpoint: endpoint,
      title: 'File transfer access',
      translateText: translateText,
    ),
  );
  if (selection != null && stableContext.mounted) await connect(selection);
}

/// Used by an already-open, unauthenticated file tab. Never closes/replaces a
/// control session and never borrows its grant or credentials.
Future<String> submitWindowsFileAccessPayload(
  String? payload, {
  required String Function(String password, bool remember) passwordLogin,
  required String Function(int method, String code) optionalLogin,
}) async {
  if (payload == null) {
    return 'Enter the receiver password or choose another access method';
  }
  Map<String, dynamic> data;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return 'Invalid file transfer access request';
    }
    data = decoded;
  } catch (_) {
    return 'Invalid file transfer access request';
  }
  if (data['lan_version'] != 1) {
    return 'Unsupported file transfer access version';
  }
  final method = data['access_method'] ?? 0;
  if (method is! int || data['lan_version'] is! int) {
    return 'Invalid file transfer access request';
  }
  if (method == 1 || method == 2 || method == 4) {
    if (data.keys.any(
      (key) =>
          !{'lan_version', 'access_method', 'temporary_code'}.contains(key),
    )) {
      return 'Optional access must not include or save credentials';
    }
    final code = data['temporary_code'];
    if (code is! String ||
        (method == 1 && !RegExp(r'^[0-9]{6}$').hasMatch(code)) ||
        (method == 2 && code.isNotEmpty)) {
      return 'Invalid temporary code';
    }
    return optionalLogin(method, code);
  }
  if (method != 0 ||
      data['username'] != '' ||
      data['password'] is! String ||
      (data['password'] as String).isEmpty ||
      data['remember'] is! bool ||
      data.keys.any(
        (key) => !{
          'lan_version',
          'username',
          'password',
          'remember',
          'access_method',
          'auto_access',
        }.contains(key),
      )) {
    return 'Invalid password-only file transfer access';
  }
  return passwordLogin(data['password'] as String, data['remember'] as bool);
}
