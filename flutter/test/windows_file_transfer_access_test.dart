import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/windows_file_transfer_access.dart';
import 'package:flutter_hbb/desktop/widgets/windows_lan_access_dialog.dart';

void main() {
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('windows-lan-connect')));
    await tester.pumpAndSettle();
  }

  Future<void> toolbar(
    WidgetTester tester,
    List<WindowsLanAccessSelection> dispatched, {bool saved = false}
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  const Text('Control session stays open'),
                  PopupMenuButton<int>(
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 1,
                        onTap: () => unawaited(
                          requestWindowsFileTransferAccess(
                            context,
                            '192.168.1.61',
                            translateText: (text) => text,
                            hasSavedPassword: (_) => saved,
                            connect: (selection) async {
                              dispatched.add(selection);
                            },
                          ),
                        ),
                        child: const Text('Transfer file'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer file'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'toolbar popup closes but manual file-only selection dispatches once',
    (tester) async {
      final calls = <WindowsLanAccessSelection>[];
      await toolbar(tester, calls);
      expect(find.text('File transfer access'), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      await submit(tester);
      expect(calls.length, 1);
      expect(jsonDecode(calls.single.payload!), {
        'lan_version': 1,
        'access_method': 2,
        'temporary_code': '',
      });
      expect(find.text('Control session stays open'), findsOneWidget);
    },
  );
  testWidgets(
    'toolbar file code forwards selected payload without control credentials',
    (tester) async {
      final calls = <WindowsLanAccessSelection>[];
      await toolbar(tester, calls);
      await tester.enterText(
        find.byKey(const ValueKey('windows-lan-password')),
        '012345',
      );
      await submit(tester);
      expect(jsonDecode(calls.single.payload!), {
        'lan_version': 1,
        'username': '',
        'password': '012345',
        'remember': false,
        'auto_access': true,
      });
    },
  );
  testWidgets('toolbar saved-password path stays null for native lookup', (
    tester,
  ) async {
    final calls = <WindowsLanAccessSelection>[];
    await toolbar(tester, calls, saved: true);
    await submit(tester);
    expect(calls.single.payload, isNull);
  });
  testWidgets('toolbar cancel never dispatches or ends control page', (
    tester,
  ) async {
    final calls = <WindowsLanAccessSelection>[];
    await toolbar(tester, calls);
    await tester.tap(find.byKey(const ValueKey('windows-lan-cancel')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Control session stays open'), findsOneWidget);
  });
  testWidgets(
    'in-tab retry requires password or other method, no misleading saved hint',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WindowsLanAccessDialog(
              endpoint: 'receiver',
              title: 'File transfer access',
              allowSavedPassword: false,
              translateText: (text) => text,
              onSubmit: (_) async {
                calls++;
                return '';
              },
              onCancel: () {},
            ),
          ),
        ),
      );
      await submit(tester);
      expect(calls, 1);
      expect(find.text('Leave empty to request manual approval'), findsOneWidget);
    },
  );
  testWidgets(
    'in-tab manual retry clears old password and reports native error',
    (tester) async {
      String? payload;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WindowsLanAccessDialog(
              endpoint: 'receiver',
              allowSavedPassword: false,
              translateText: (text) => text,
              onSubmit: (selection) async {
                payload = selection.payload;
                return 'Connection is no longer available';
              },
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('windows-lan-password')),
        'test-secret',
      );
      await tester.enterText(find.byKey(const ValueKey('windows-lan-password')), '');
      await submit(tester);
      expect(jsonDecode(payload!), {
        'lan_version': 1,
        'access_method': 2,
        'temporary_code': '',
      });
      expect(find.text('Connection is no longer available'), findsOneWidget);
    },
  );
  testWidgets(
    'pending submission disables duplicate submit and tolerates disposal',
    (tester) async {
      final done = Completer<String>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WindowsLanAccessDialog(
              endpoint: 'receiver',
              allowSavedPassword: false,
              translateText: (text) => text,
              onSubmit: (_) {
                calls++;
                return done.future;
              },
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('windows-lan-connect')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('windows-lan-connect')),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      done.complete('Late error');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('in-tab cancel invokes only its scoped callback', (tester) async {
    var fileCancel = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('Control session stays open'),
              WindowsLanAccessDialog(
                endpoint: 'receiver',
                translateText: (text) => text,
                onSubmit: (_) async => '',
                onCancel: () {
                  fileCancel++;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('windows-lan-cancel')));
    await tester.pump();
    expect(fileCancel, 1);
    expect(find.text('Control session stays open'), findsOneWidget);
  });
  test('password retry calls password API without username', () async {
    final passwordCalls = <List<Object>>[];
    final error = await submitWindowsFileAccessPayload(
      jsonEncode({
        'lan_version': 1,
        'username': '',
        'password': 'test-only',
        'remember': true,
      }),
      passwordLogin: (password, remember) {
        passwordCalls.add([password, remember]);
        return '';
      },
      optionalLogin: (_, __) => throw StateError('Wrong API'),
    );
    expect(error, isEmpty);
    expect(passwordCalls, [
      ['test-only', true],
    ]);
  });
  for (final method in [1, 2]) {
    test(
      'method$method retries pending file channel using optional API only',
      () async {
        final calls = <List<Object>>[];
        final code = method == 1 ? '012345' : '';
        final error = await submitWindowsFileAccessPayload(
          jsonEncode({
            'lan_version': 1,
            'access_method': method,
            'temporary_code': code,
          }),
          passwordLogin: (_, __) =>
              throw StateError('Must not fall back to passwords'),
          optionalLogin: (value, code) {
            calls.add([value, code]);
            return '';
          },
        );
        expect(error, isEmpty);
        expect(calls, [
          [method, code],
        ]);
      },
    );
  }
  test(
    'invalid/mixed/foreign credential payloads never call any login API',
    () async {
      var calls = 0;
      final invalid = <String?>[
        null,
        '',
        '[]',
        '{}',
        jsonEncode({
          'lan_version': 2,
          'access_method': 2,
          'temporary_code': '',
        }),
        jsonEncode({
          'lan_version': 1,
          'access_method': 1.0,
          'temporary_code': '123456',
        }),
        jsonEncode({
          'lan_version': 1,
          'access_method': 1,
          'temporary_code': '12345',
        }),
        jsonEncode({
          'lan_version': 1,
          'access_method': 2,
          'temporary_code': '123456',
        }),
        for (final extra in [
          'password',
          'remember',
          'username',
          'identity_id',
          'bind_identity',
        ])
          jsonEncode({
            'lan_version': 1,
            'access_method': 2,
            'temporary_code': '',
            extra: '',
          }),
        jsonEncode({
          'lan_version': 1,
          'username': 'user',
          'password': 'test',
          'remember': false,
        }),
      ];
      for (final payload in invalid) {
        expect(
          await submitWindowsFileAccessPayload(
            payload,
            passwordLogin: (_, __) {
              calls++;
              return '';
            },
            optionalLogin: (_, __) {
              calls++;
              return '';
            },
          ),
          isNotEmpty,
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'actual toolbar, IPC, duplicate-tab and pending dialog wiring guards',
    () {
      final toolbar = File(
        'lib/common/widgets/toolbar.dart',
      ).readAsStringSync();
      expect(
        toolbar,
        contains('unawaited(connectWindowsFileTransfer(context, id))'),
      );
      final common = File('lib/common.dart').readAsStringSync();
      expect(common, contains('selection.endpoint, isFileTransfer: true'));
      expect(
        common,
        contains('password: selection.payload, lanAccessSelected: true'),
      );
      final home = File(
        'lib/desktop/pages/desktop_home_page.dart',
      ).readAsStringSync();
      expect(home, contains("password: call.arguments['password']"));
      final tabs = File(
        'lib/desktop/pages/file_manager_tab_page.dart',
      ).readAsStringSync();
      expect(tabs, contains('ffi.ffiModel.pi.version.isEmpty'));
      expect(tabs, contains("submitWindowsFileAccessPayload(args['password']"));
      expect(tabs, isNot(contains('sessionClose(')));
      final model = File('lib/models/model.dart').readAsStringSync();
      expect(
        model,
        contains(
          'isWindows && parent.target?.connType == ConnType.fileTransfer',
        ),
      );
      expect(model, contains('allowSavedPassword: false'));
      expect(model, contains('closeConnection(id: peerId)'));
      expect(model, isNot(contains('Enter the access username and password')));
    },
  );
}
