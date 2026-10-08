import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter_hbb/models/session_chat_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MessageBody body(String label) => MessageBody(ChatUser(id: 'test'), [
    ChatMessage(
      user: ChatUser(id: 'test'),
      createdAt: DateTime(2026),
      text: label,
    ),
  ]);

  test('same peer on different incoming sessions has distinct keys', () {
    final first = MessageKey('peer', 1), second = MessageKey('peer', 2);
    expect(first, isNot(second));
    expect({first, second}.length, 2);
    expect(first, MessageKey('peer', 1));
    expect(first.hashCode, MessageKey('peer', 1).hashCode);
  });

  test('outgoing and incoming conversation identities remain separate', () {
    expect(MessageKey('peer', -1), isNot(MessageKey('peer', 1)));
    expect(MessageKey('peer', -1).isOut, true);
    expect(MessageKey('other-peer', -1), isNot(MessageKey('peer', -1)));
  });

  test(
    'removal empties a list held by the old UI as well as removing map entry',
    () {
      final memory = SessionChatMemory(), key = MessageKey('peer', 1);
      final oldBody = body('old session');
      final heldList = oldBody.chatMessages;
      memory.messages[key] = oldBody;
      memory.removeConnection(1);
      expect(memory.messages, isEmpty);
      expect(heldList, isEmpty);
      expect(oldBody.chatMessages, isEmpty);
    },
  );

  test('disconnect of one same-peer session preserves the other', () {
    final memory = SessionChatMemory();
    memory.messages[MessageKey('peer', 1)] = body('first');
    memory.messages[MessageKey('peer', 2)] = body('second');
    memory.removeConnection(1);
    expect(memory.messages.length, 1);
    expect(
      memory.messages[MessageKey('peer', 2)]!.chatMessages.single.text,
      'second',
    );
  });

  test(
    'snapshot clears missing/disconnected sessions but preserves outgoing',
    () {
      final memory = SessionChatMemory();
      final removed = body('ended');
      memory.messages[MessageKey('one', 1)] = removed;
      memory.messages[MessageKey('two', 2)] = body('connected');
      memory.messages[MessageKey('three', -1)] = body('outgoing');
      memory.retainIncoming({2});
      expect(removed.chatMessages, isEmpty);
      expect(memory.messages.keys.toSet(), {
        MessageKey('two', 2),
        MessageKey('three', -1),
      });
    },
  );

  test('outgoing reset removes all outgoing keys, not integer lookup', () {
    final memory = SessionChatMemory();
    final oldOutgoing = body('outgoing');
    memory.messages[MessageKey('one', -1)] = oldOutgoing;
    memory.messages[MessageKey('two', -1)] = body('other outgoing');
    memory.messages[MessageKey('incoming', 3)] = body('incoming');
    memory.clearOutgoing();
    expect(oldOutgoing.chatMessages, isEmpty);
    expect(memory.messages.keys.single, MessageKey('incoming', 3));
  });

  test(
    'reconnect never inherits history even when peer and connId are reused',
    () {
      final memory = SessionChatMemory(), key = MessageKey('peer', 1);
      memory.messages[key] = body('old');
      memory.removeConnection(1);
      memory.messages[MessageKey('peer', 1)] = MessageBody(
        ChatUser(id: 'test'),
        [],
      );
      expect(memory.messages[key]!.chatMessages, isEmpty);
    },
  );

  test('clear releases every conversation and is idempotent', () {
    final memory = SessionChatMemory();
    final first = body('incoming'), second = body('outgoing');
    memory.messages[MessageKey('one', 1)] = first;
    memory.messages[MessageKey('two', -1)] = second;
    memory.clear();
    memory.clear();
    memory.removeConnection(999);
    expect(memory.messages, isEmpty);
    expect(first.chatMessages, isEmpty);
    expect(second.chatMessages, isEmpty);
  });
}
