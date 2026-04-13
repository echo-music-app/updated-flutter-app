import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';

class UpdateOwnProfileUseCase {
  const UpdateOwnProfileUseCase({required this.repository});

  final ProfileRepository repository;

  Future<ProfileHeader> call({String? bio}) {
    return repository.updateOwnProfile(bio: bio);
  }
}
