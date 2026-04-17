class FollowRequestNotification {
  const FollowRequestNotification({
    required this.requesterUserId,
    required this.requesterUsername,
    required this.requestedAt,
  });

  final String requesterUserId;
  final String requesterUsername;
  final DateTime requestedAt;
}

class PostActivityNotification {
  const PostActivityNotification({
    required this.id,
    required this.actorUserId,
    required this.actorUsername,
    required this.postId,
    required this.activityType,
    required this.createdAt,
    this.commentPreview,
  });

  final String id;
  final String actorUserId;
  final String actorUsername;
  final String postId;
  final String activityType;
  final DateTime createdAt;
  final String? commentPreview;
}

class NotificationsAuthException implements Exception {
  const NotificationsAuthException([this.message]);
  final String? message;
}

class NotificationsLoadException implements Exception {
  const NotificationsLoadException([this.message]);
  final String? message;
}

abstract interface class NotificationsRepository {
  Future<List<FollowRequestNotification>> listIncomingFollowRequests();
  Future<List<PostActivityNotification>> listPostActivityNotifications();
  Future<void> acceptFollowRequest(String requesterUserId);
}
