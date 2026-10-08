import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter_hbb/models/chat_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class _TestSession implements FFI {
  @override
  final sessionId = const Uuid().v4obj();
  @override
  bool closed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TestSession session;
  late ChatModel model;

  void insert(String peer, int connection, String text) {
    model.insertMessage(
      MessageKey(peer, connection),
      ChatMessage(
        user: ChatUser(id: peer),
        createdAt: DateTime(2026),
        text: text,
      ),
    );
  }

  setUp(() {
    session = _TestSession();
    model = ChatModel(WeakReference(session), localUserName: 'Test');
  });
  tearDown(() => model.dispose());

  test('selected session disconnect drops messages, draft and latest key', () {
    insert('peer', 1, 'old');
    model.latestReceivedKey = MessageKey('peer', 1);
    model.textController.text = 'unsent';
    model.removeSession(1);
    expect(model.messages, isEmpty);
    expect(model.textController.text, isEmpty);
    expect(model.currentKey.peerId, isEmpty);
    expect(model.latestReceivedKey, isNull);
  });

  test('other session disconnect preserves selected chat and draft', () {
    insert('selected', 1, 'keep');
    insert('other', 2, 'drop');
    model.latestReceivedKey = MessageKey('other', 2);
    model.textController.text = 'keep draft';
    model.removeSession(2);
    expect(model.messages.keys.single, MessageKey('selected', 1));
    expect(model.textController.text, 'keep draft');
    expect(model.currentKey, MessageKey('selected', 1));
    expect(model.latestReceivedKey, isNull);
  });

  test(
    'outgoing reconnect reset fixes integer lookup and retains incoming',
    () {
      insert('outgoing', -1, 'drop');
      insert('incoming', 2, 'keep');
      model.textController.text = 'outgoing draft';
      model.resetClientMode();
      expect(model.messages.keys.single, MessageKey('incoming', 2));
      expect(model.textController.text, isEmpty);
      expect(model.currentKey.peerId, isEmpty);
    },
  );

  test('new incoming connId never moves old same-peer message list', () {
    insert('same-peer', 1, 'old');
    model.updateConnIdOfKey(MessageKey('same-peer', 2));
    expect(model.messages.containsKey(MessageKey('same-peer', 2)), false);
    model.removeSession(1);
    insert('same-peer', 2, 'new');
    expect(
      model.messages[MessageKey('same-peer', 2)]!.chatMessages.single.text,
      'new',
    );
  });

  test(
    'authoritative snapshot recovers missed disconnect and clears draft',
    () {
      insert('ended', 1, 'drop');
      insert('alive', 2, 'keep');
      model.textController.text = 'drop draft';
      model.retainIncomingSessions({2});
      expect(model.messages.keys.single, MessageKey('alive', 2));
      expect(model.textController.text, isEmpty);
    },
  );

  test('close clears held list, text, selection and cooling state', () {
    insert('outgoing', -1, 'drop');
    final oldList = model.messages.values.single.chatMessages;
    model.textController.text = 'drop draft';
    model.buzzerCoolingDown = true;
    model.close();
    expect(oldList, isEmpty);
    expect(model.messages, isEmpty);
    expect(model.textController.text, isEmpty);
    expect(model.buzzerCoolingDown, false);
  });

  test('late outgoing receive after close cannot resurrect chat', () async {
    await model.receive(-1, 'late');
    expect(model.messages, isEmpty);
  });

  test('dispose clears list references even without a prior close', () {
    insert('peer', 1, 'drop');
    final oldList = model.messages.values.single.chatMessages;
    final oldController = model.textController;
    oldController.text = 'unsent';
    model.dispose();
    expect(oldList, isEmpty);
    expect(oldController.text, isEmpty);
    // tearDown must not dispose the same ChangeNotifier twice.
    model = ChatModel(WeakReference(session), localUserName: 'Test');
  });
}
