import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';

class UploadOwnAvatarUseCase {
  const UploadOwnAvatarUseCase({required this.repository});

  final ProfileRepository repository;

  Future<ProfileHeader> call(String filePath) {
    return repository.uploadOwnAvatar(filePath);
  }
}
