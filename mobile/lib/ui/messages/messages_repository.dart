class MessageThreadSummary {
  const MessageThreadSummary({
    required this.userId,
    required this.username,
    required this.lastMessagePreview,
    required this.lastMessageAt,
  });

  final String userId;
  final String username;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderUserId,
    required this.senderUsername,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String senderUserId;
  final String senderUsername;
  final String text;
  final DateTime createdAt;
  final bool isMine;
}

class DirectMessageThread {
  const DirectMessageThread({
    required this.targetUserId,
    required this.targetUsername,
    required this.items,
  });

  final String targetUserId;
  final String targetUsername;
  final List<DirectMessage> items;
}

abstract class MessagesRepository {
  Future<List<MessageThreadSummary>> listThreads();

  Future<DirectMessageThread> getConversation(String userId);

  Future<DirectMessage> sendMessage(String userId, String text);
}

class MessagesAuthException implements Exception {
  const MessagesAuthException([this.message]);
  final String? message;
}

class MessagesPermissionException implements Exception {
  const MessagesPermissionException([this.message]);
  final String? message;
}

class MessagesLoadException implements Exception {
  const MessagesLoadException([this.message]);
  final String? message;
}
