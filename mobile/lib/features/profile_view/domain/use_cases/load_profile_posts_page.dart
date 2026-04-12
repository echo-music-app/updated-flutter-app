import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';

class LoadProfilePostsPageUseCase {
  const LoadProfilePostsPageUseCase({required this.repository});

  final ProfileRepository repository;

  /// Loads a page of posts for the given [target].
  ///
  /// Pass [cursor] for load-more requests; omit for first page.
  Future<ProfilePostsPage> call(
    ProfileRouteTarget target, {
    int pageSize = 20,
    String? cursor,
  }) async {
    switch (target.mode) {
      case ProfileMode.own:
        return repository.getOwnPosts(pageSize: pageSize, cursor: cursor);
      case ProfileMode.other:
        final userId = target.targetUserId;
        if (userId == null || userId.isEmpty) {
          throw const ProfileLoadException(
            'Missing targetUserId for other mode',
          );
        }
        return repository.getUserPosts(
          userId,
          pageSize: pageSize,
          cursor: cursor,
        );
    }
  }
}
