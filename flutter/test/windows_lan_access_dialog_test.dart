import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/windows_lan_access_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    void Function(WindowsLanAccessSelection?) result, {
    bool edit = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result(
                    await showDialog<WindowsLanAccessSelection>(
                      context: context,
                      builder: (_) => WindowsLanAccessDialog(
                        endpoint: '192.168.1.61',
                        editEndpoint: edit,
                        translateText: (text) => text,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> method(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('windows-lan-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('windows-lan-connect')));
    await tester.pumpAndSettle();
  }

  testWidgets('password-only payload retains remember option', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    expect(find.text('Username'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-password')),
      'secret',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await submit(tester);
    expect(result!.endpoint, '192.168.1.61');
    expect(jsonDecode(result!.payload!), {
      'lan_version': 1,
      'username': '',
      'password': 'secret',
      'remember': true,
    });
  });
  testWidgets('blank password preserves native saved-credential path', (
    tester,
  ) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    await submit(tester);
    expect(result, isNotNull);
    expect(result!.payload, isNull);
  });
  testWidgets('temporary code submits only existing optional wire fields', (
    tester,
  ) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    await method(tester, 'Temporary code');
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-code')),
      '123456',
    );
    await submit(tester);
    expect(jsonDecode(result!.payload!), {
      'lan_version': 1,
      'access_method': 1,
      'temporary_code': '123456',
    });
  });
  testWidgets('invalid code never submits', (tester) async {
    var submitted = false;
    await open(tester, (_) => submitted = true);
    await method(tester, 'Temporary code');
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-code')),
      '12345',
    );
    await submit(tester);
    expect(submitted, isFalse);
    expect(find.text('Enter a 6-digit temporary code'), findsOneWidget);
  });
  testWidgets('code field accepts ASCII digits only', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    await method(tester, 'Temporary code');
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-code')),
      'a123456',
    );
    await submit(tester);
    expect(jsonDecode(result!.payload!)['temporary_code'], '123456');
  });
  testWidgets('manual approval requests acceptance without credentials', (
    tester,
  ) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    await method(tester, 'Manual approval');
    expect(
      find.text(
        'A request appears on the receiver. Control starts only after acceptance.',
      ),
      findsOneWidget,
    );
    await submit(tester);
    expect(jsonDecode(result!.payload!), {
      'lan_version': 1,
      'access_method': 2,
      'temporary_code': '',
    });
  });
  testWidgets('method switch clears password and remember state', (
    tester,
  ) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-password')),
      'secret',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await method(tester, 'Manual approval');
    await method(tester, 'Password / saved password');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('windows-lan-password')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    await submit(tester);
    expect(result!.payload, isNull);
  });
  testWidgets('switching code to manual discards the code', (tester) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value);
    await method(tester, 'Temporary code');
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-code')),
      '123456',
    );
    await method(tester, 'Manual approval');
    await submit(tester);
    expect(jsonDecode(result!.payload!)['temporary_code'], isEmpty);
  });
  testWidgets('changing endpoint discards credentials for previous peer', (
    tester,
  ) async {
    WindowsLanAccessSelection? result;
    await open(tester, (value) => result = value, edit: true);
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-password')),
      'secret',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-endpoint')),
      '192.168.1.12',
    );
    await submit(tester);
    expect(result!.endpoint, '192.168.1.12');
    expect(result!.payload, isNull);
  });
  testWidgets('empty endpoint blocks submission', (tester) async {
    var submitted = false;
    await open(tester, (_) => submitted = true, edit: true);
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-endpoint')),
      '  ',
    );
    await submit(tester);
    expect(submitted, isFalse);
    expect(
      find.text('Enter the receiver IP address or hostname'),
      findsOneWidget,
    );
  });
  testWidgets('cancel returns no connection selection', (tester) async {
    WindowsLanAccessSelection? result;
    var returned = false;
    await open(tester, (value) {
      result = value;
      returned = true;
    });
    await tester.enterText(
      find.byKey(const ValueKey('windows-lan-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('windows-lan-cancel')));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });
  testWidgets('compact dialog scrolls without overflow', (tester) async {
    tester.view.physicalSize = const Size(440, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, (_) {}, edit: true);
    expect(tester.takeException(), isNull);
    await method(tester, 'Manual approval');
    expect(tester.takeException(), isNull);
    await submit(tester);
    expect(tester.takeException(), isNull);
  });
  test(
    'central Windows peer routing prompts before dispatch and forwards payload',
    () {
      final source = File('lib/common.dart').readAsStringSync();
      final start = source.indexOf('bool lanAccessSelected = false');
      expect(start, greaterThan(0));
      final routing = source.substring(
        start,
        source.indexOf('class SimpleWrapper', start),
      );
      expect(routing, contains('isWindows &&'));
      expect(routing, contains('!lanAccessSelected &&'));
      expect(routing, contains('(password == null || password.isEmpty)'));
      expect(routing, contains('password = selection.payload'));
      expect(
        routing.indexOf('WindowsLanAccessDialog'),
        lessThan(routing.indexOf('connectMainDesktop(')),
      );
      expect(routing, contains('password: password'));
      expect(routing, contains("'password': password"));
      final add = File(
        'lib/desktop/pages/connection_page.dart',
      ).readAsStringSync();
      expect(
        add,
        contains('WindowsLanAccessDialog(endpoint: _idController.id'),
      );
      expect(add, contains('lanAccessSelected: true'));
      expect(add, contains('password: selection.payload'));
    },
  );
}
