import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:uuid/uuid.dart';

void main() {
  final path = Platform.environment['SUBNETDESK_TEST_NATIVE'];
  final enabled = Platform.isWindows && path != null;
  // FRB permits one binding instance per isolate, shared by both smoke checks.
  RustdeskImpl? native;
  setUpAll(() {
    if (enabled) native = RustdeskImpl(DynamicLibrary.open(path));
  });
  test('actual private DLL reports new native public version', () async {
    expect(await native!.mainGetVersion(), '1.4.1');
  }, skip: !enabled);
  test(
    'session approval ABI rejects malformed permissions before granting access',
    () async {
      expect(
        await native!.cmDecideLanRequestWithPermissions(
          id: -1,
          nonce: '',
          accept: true,
          permissions: '{"keyboard":true}',
        ),
        'Invalid session permissions; access was not granted',
      );
    },
    skip: !enabled,
  );
  test(
    'new optional-file ABI fails closed for missing session without touching live sessions',
    () {
      for (final method in [1, 2]) {
        expect(
          native!.sessionLoginOptionalFileAccess(
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
