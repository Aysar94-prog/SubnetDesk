import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/desktop/widgets/receiver_only_settings.dart';

void main() {
  testWidgets(
    'Settings can lock, reject a wrong password, unlock, persist and relock',
    (tester) async {
      final options = <String, String>{'incoming-only-initialized': 'unlocked'};
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: ReceiverOnlySettings(
            initiallyLocked: options['incoming-only-initialized'] == 'locked',
            readOption: (key) async => options[key] ?? '',
            writeOption: (key, value) async {
              options[key] = value;
            },
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'chosen-password');
      await tester.tap(find.text('Lock as receiver-only'));
      await tester.pumpAndSettle();
      expect(options['incoming-only'], 'Y');
      expect(
        options['incoming-only-password'],
        sha256.convert(utf8.encode('chosen-password')).toString(),
      );
      expect(options['incoming-only-initialized'], 'locked');
      expect(
        find.text('This device is currently receiver-only.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect unlock password.'), findsOneWidget);
      expect(options['incoming-only-initialized'], 'locked');
      await tester.enterText(find.byType(TextField).last, 'chosen-password');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(options['incoming-only-initialized'], 'unlocked');
      expect(options['incoming-only-password'], '');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(
        find.text('This device can both send and receive.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'new-password');
      await tester.tap(find.text('Lock as receiver-only'));
      await tester.pumpAndSettle();
      expect(options['incoming-only-initialized'], 'locked');
      expect(
        options['incoming-only-password'],
        sha256.convert(utf8.encode('new-password')).toString(),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'device policy overrides all account-local controls and refreshes while open',
    (tester) async {
      final options = <String, String>{
        'incoming-only-scope': 'device',
        'incoming-only': 'Y',
      };
      int writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiverOnlySettings(
              initiallyLocked: false,
              readOption: (key) async => options[key] ?? '',
              writeOption: (key, value) async {
                writes++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Device policy: receiver-only.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Unlock'), findsNothing);
      options['incoming-only'] = '';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Device policy: send-and-receive.'), findsOneWidget);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
