class FriendListItem {
  const FriendListItem({
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
}

enum FriendListType { followers, following }

abstract class FriendsRepository {
  Future<List<FriendListItem>> listFriends(FriendListType type);
}

class FriendsAuthException implements Exception {
  const FriendsAuthException([this.message]);
  final String? message;
}

class FriendsLoadException implements Exception {
  const FriendsLoadException([this.message]);
  final String? message;
}
