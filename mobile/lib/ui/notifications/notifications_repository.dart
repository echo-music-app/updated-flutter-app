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
  Future<void> acceptFollowRequest(String requesterUserId);
}
