enum ProfileMode { own, other }

enum ProfileImageState { placeholder }

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
    this.bio,
    this.preferredGenres = const [],
    this.isArtist = false,
    this.imageState = ProfileImageState.placeholder,
  });

  final String id;
  final String username;
  final String? bio;
  final List<String> preferredGenres;
  final bool isArtist;
  final DateTime createdAt;
  final ProfileImageState imageState;
}
