import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/windows_lan_access_dialog.dart';
import 'package:flutter_hbb/desktop/widgets/windows_file_transfer_access.dart';

void main() {
  Future<Map<String, dynamic>> submit(WidgetTester tester, String password,
      {bool remember = false}) async {
    WindowsLanAccessSelection? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
        TextButton(onPressed: () async {
          result = await showDialog<WindowsLanAccessSelection>(context: context,
              builder: (_) => WindowsLanAccessDialog(endpoint: '192.168.50.103',
                  translateText: (text) => text));
        }, child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('windows-lan-password')), password);
    if (remember) await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.byKey(const ValueKey('windows-lan-connect')));
    await tester.pumpAndSettle();
    return jsonDecode(result!.payload!) as Map<String, dynamic>;
  }

  for (final password in ['abc', 'long-password-!42', ' كلمة سر ', '12345', '1234567']) {
    testWidgets('unattended input retains unified AUTO login: ${password.length} characters', (tester) async {
      final payload = await submit(tester, password, remember: true);
      expect(payload['access_method'], 4);
      expect(payload['temporary_code'], password);
      expect(payload.containsKey('username'), isFalse);
      expect(payload.containsKey('password'), isFalse);
      String? delivered;
      final error = await submitWindowsFileAccessPayload(jsonEncode(payload),
          passwordLogin: (_, __) => throw StateError('Unified login was replaced'),
          optionalLogin: (method, value) { expect(method, 4); delivered = value; return ''; });
      expect(error, isEmpty);
      expect(delivered, password);
    });
  }
  testWidgets('six-digit input retains password-or-code negotiation without saving code', (tester) async {
    final payload = await submit(tester, '012345', remember: true);
    expect(payload['access_method'], 4);
    expect(payload['temporary_code'], '012345');
    expect(payload.containsKey('password'), isFalse);
    expect(payload.containsKey('remember'), isFalse);
  });
  testWidgets('blank input retains manual request without credentials', (tester) async {
    final payload = await submit(tester, '');
    expect(payload['access_method'], 4);
    expect(payload['temporary_code'], '');
    expect(payload.containsKey('password'), isFalse);
  });
  testWidgets('manual request remains available on a file-only retry', (tester) async {
    WindowsLanAccessSelection? submitted;
    await tester.pumpWidget(MaterialApp(home: WindowsLanAccessDialog(
        endpoint: 'receiver', allowSavedPassword: false,
        translateText: (text) => text,
        onSubmit: (value) async { submitted = value; return ''; })));
    await tester.tap(find.byKey(const ValueKey('windows-lan-connect')));
    await tester.pumpAndSettle();
    expect(jsonDecode(submitted!.payload!)['temporary_code'], '');
    expect(jsonDecode(submitted!.payload!)['access_method'], 4);
  });
}
