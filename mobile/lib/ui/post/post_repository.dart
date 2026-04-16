import 'package:mobile/ui/home/home_view_model.dart';

abstract class PostRepository {
  Future<void> createPost({
    required PostPrivacy privacy,
    String? text,
    String? spotifyUrl,
  });
}

class PostAuthException implements Exception {
  const PostAuthException([this.message]);

  final String? message;
}

class PostCreateException implements Exception {
  const PostCreateException([this.message]);

  final String? message;
}
