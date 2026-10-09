import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:uuid/uuid.dart';

void main() {
  final path = Platform.environment['SUBNETDESK_TEST_NATIVE'];
  final enabled = Platform.isWindows && path != null;
  test('actual private DLL reports new native public version', () async {
    final native = RustdeskImpl(DynamicLibrary.open(path!));
    expect(await native.mainGetVersion(), '1.3.8');
  }, skip: !enabled);
  test(
    'new optional-file ABI fails closed for missing session without touching live sessions',
    () {
      final native = RustdeskImpl(DynamicLibrary.open(path!));
      for (final method in [1, 2]) {
        expect(
          native.sessionLoginOptionalFileAccess(
            sessionId: const Uuid().v4obj(),
            accessMethod: method,
            temporaryCode: method == 1 ? '012345' : '',
          ),
          'Session is no longer available',
        );
      }
    },
    skip: !enabled,
  );
}
