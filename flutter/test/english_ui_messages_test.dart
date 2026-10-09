import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app UI has no hardcoded Arabic messages', () {
    final arabic = RegExp(r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]');
    final offenders = Directory('lib').listSync(recursive: true).whereType<File>()
        .where((file) => file.path.endsWith('.dart') && arabic.hasMatch(file.readAsStringSync()))
        .map((file) => file.path).toList();
    expect(offenders, isEmpty);
  });
  test('manual approval waiting messages use English source keys', () {
    expect(File('lib/models/model.dart').readAsStringSync(),
      contains("translate('Waiting for receiver approval (up to 60 seconds)')"));
    expect(File('lib/desktop/pages/server_page.dart').readAsStringSync(),
      contains('translate("Waiting for approval")'));
  });
}
