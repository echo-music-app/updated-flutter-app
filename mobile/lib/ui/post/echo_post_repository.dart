import 'package:dio/dio.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/ui/post/post_repository.dart';

class EchoPostRepository implements PostRepository {
  EchoPostRepository({
    required String echoBaseUrl,
    required Future<String?> Function() getAccessToken,
    Future<String?> Function()? refreshAccessToken,
    Dio? dio,
  }) : _echoBaseUrl = echoBaseUrl,
       _getAccessToken = getAccessToken,
       _refreshAccessToken = refreshAccessToken,
       _dio = dio ?? Dio();

  final String _echoBaseUrl;
  final Future<String?> Function() _getAccessToken;
  final Future<String?> Function()? _refreshAccessToken;
  final Dio _dio;

  Future<Options> _authOptions() async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) {
      throw const PostAuthException('No active session');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Response<dynamic>> _postWithAuthRetry(
    String path, {
    Object? data,
  }) async {
    try {
      return await _dio.post(path, data: data, options: await _authOptions());
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || _refreshAccessToken == null) {
        rethrow;
      }
      final refreshedToken = await _refreshAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }
      return _dio.post(
        path,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $refreshedToken'}),
      );
    }
  }

  @override
  Future<void> createPost({
    required PostPrivacy privacy,
    String? text,
    String? spotifyUrl,
  }) async {
    final trimmedText = text?.trim();
    final trimmedSpotify = spotifyUrl?.trim();
    try {
      await _postWithAuthRetry(
        '$_echoBaseUrl/v1/posts',
        data: <String, dynamic>{
          'privacy': _toApiPrivacy(privacy),
          if (trimmedText != null && trimmedText.isNotEmpty)
            'text': trimmedText,
          if (trimmedSpotify != null && trimmedSpotify.isNotEmpty)
            'spotify_url': trimmedSpotify,
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw PostAuthException(e.message);
      }
      throw PostCreateException(e.message);
    }
  }

  String _toApiPrivacy(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return 'Public';
      case PostPrivacy.friendsOnly:
        return 'Friends';
      case PostPrivacy.onlyMe:
        return 'OnlyMe';
    }
  }
}
