import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';

/// Thrown when a profile is not found (HTTP 404 or invalid userId 422).
class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException([this.message]);
  final String? message;
}

/// Thrown when the session is expired or unauthorized (HTTP 401).
class ProfileAuthException implements Exception {
  const ProfileAuthException([this.message]);
  final String? message;
}

/// Thrown for transient/unexpected errors.
class ProfileLoadException implements Exception {
  const ProfileLoadException([this.message]);
  final String? message;
}

abstract interface class ProfileRepository {
  /// Fetches the authenticated user's own profile header.
  Future<ProfileHeader> getOwnProfile();

  /// Fetches another user's public profile header.
  ///
  /// Throws [ProfileNotFoundException] for 404/422.
  /// Throws [ProfileAuthException] for 401.
  Future<ProfileHeader> getUserProfile(String userId);

  /// Fetches a page of the authenticated user's own posts.
  Future<ProfilePostsPage> getOwnPosts({int pageSize = 20, String? cursor});

  /// Fetches a page of another user's public posts.
  ///
  /// Throws [ProfileNotFoundException] for 422.
  /// Throws [ProfileAuthException] for 401.
  Future<ProfilePostsPage> getUserPosts(
    String userId, {
    int pageSize = 20,
    String? cursor,
  });

  /// Updates the authenticated user's profile fields.
  ///
  /// Throws [ProfileAuthException] for 401.
  Future<ProfileHeader> updateOwnProfile({String? bio});

  /// Uploads/replaces authenticated user's avatar image.
  Future<ProfileHeader> uploadOwnAvatar(String filePath);

  /// Returns relationship status between authenticated user and [userId].
  Future<FollowRelationStatus> getFollowStatus(String userId);

  /// Sends a follow request to [userId].
  Future<void> sendFollowRequest(String userId);

  /// Accepts an incoming follow request from [userId].
  Future<void> acceptFollowRequest(String userId);
}
