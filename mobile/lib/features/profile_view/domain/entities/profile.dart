enum ProfileMode { own, other }

enum ProfileImageState { placeholder }

enum FollowRelationStatus {
  none,
  pendingOutgoing,
  pendingIncoming,
  accepted,
  self,
}

class ProfileRouteTarget {
  const ProfileRouteTarget({
    required this.mode,
    this.targetUserId,
    this.isSelfResolved = false,
  });

  final ProfileMode mode;
  final String? targetUserId;
  final bool isSelfResolved;
}

class ProfileHeader {
  const ProfileHeader({
    required this.id,
    required this.username,
    required this.createdAt,
    this.avatarUrl,
    this.bio,
    this.preferredGenres = const [],
    this.isArtist = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.imageState = ProfileImageState.placeholder,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final List<String> preferredGenres;
  final bool isArtist;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;
  final ProfileImageState imageState;
}
