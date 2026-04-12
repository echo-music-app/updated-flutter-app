import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';

class LoadProfileHeaderUseCase {
  const LoadProfileHeaderUseCase({required this.repository});

  final ProfileRepository repository;

  /// Loads profile header based on the resolved [target].
  ///
  /// Throws [ProfileNotFoundException], [ProfileAuthException], or
  /// [ProfileLoadException] on failure.
  Future<ProfileHeader> call(ProfileRouteTarget target) async {
    switch (target.mode) {
      case ProfileMode.own:
        return repository.getOwnProfile();
      case ProfileMode.other:
        final userId = target.targetUserId;
        if (userId == null || userId.isEmpty) {
          throw const ProfileLoadException(
            'Missing targetUserId for other mode',
          );
        }
        return repository.getUserProfile(userId);
    }
  }
}
