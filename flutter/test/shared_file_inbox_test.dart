import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/shared_file_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('subnetdesk/share');
  test(
    'acknowledges only explicitly queued files and keeps remaining files',
    () async {
      final pending = ['/Transfers/Shared/a.txt', '/Transfers/Shared/b.txt'];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'pending')
              return {'files': List.of(pending), 'errors': <String>[]};
            if (call.method == 'acknowledge')
              pending.removeWhere(
                (path) => (call.arguments as List).contains(path),
              );
            return null;
          });
      final inbox = SharedFileInbox();
      await inbox.refresh();
      expect(inbox.files.length, 2);
      await inbox.acknowledge([inbox.files.first]);
      expect(inbox.files, ['/Transfers/Shared/b.txt']);
      inbox.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test('channel failure is visible and retry can recover', () async {
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (fail) throw PlatformException(code: 'unavailable');
          return {
            'files': ['/Transfers/Shared/a.txt'],
            'errors': <String>[],
          };
        });
    final inbox = SharedFileInbox();
    await inbox.refresh();
    expect(inbox.error, isNotNull);
    fail = false;
    await inbox.refresh();
    expect(inbox.files.length, 1);
    inbox.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
