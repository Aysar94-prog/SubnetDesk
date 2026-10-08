import 'package:dash_chat_2/dash_chat_2.dart';

/// Chat belongs to a connection, not a peer's lifetime across reconnections.
class MessageKey {
  final String peerId;
  final int connId;
  bool get isOut => connId == -1;

  MessageKey(this.peerId, this.connId);

  @override
  bool operator ==(Object other) =>
      other is MessageKey && other.peerId == peerId && other.connId == connId;

  @override
  int get hashCode => Object.hash(peerId, connId);
}

class MessageBody {
  ChatUser chatUser;
  List<ChatMessage> chatMessages;
  MessageBody(this.chatUser, this.chatMessages);

  void insert(ChatMessage message) => chatMessages.insert(0, message);
  void clear() => chatMessages.clear();
}

/// Logical in-memory cleanup only; no files, persistence or secret overwrites.
class SessionChatMemory {
  final Map<MessageKey, MessageBody> messages = {};

  void _removeWhere(bool Function(MessageKey) shouldRemove) {
    for (final key in messages.keys.where(shouldRemove).toList()) {
      // Clear before removal so a mounted view holding this list sees it empty.
      messages.remove(key)?.clear();
    }
  }

  void removeConnection(int connId) =>
      _removeWhere((key) => key.connId == connId);

  void clearOutgoing() => _removeWhere((key) => key.isOut);

  void retainIncoming(Set<int> connectedIds) =>
      _removeWhere((key) => !key.isOut && !connectedIds.contains(key.connId));

  void clear() => _removeWhere((_) => true);
}
