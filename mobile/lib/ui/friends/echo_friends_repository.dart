import 'package:dio/dio.dart';
import 'package:mobile/ui/friends/friends_repository.dart';

class EchoFriendsRepository implements FriendsRepository {
  EchoFriendsRepository({
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
      throw const FriendsAuthException('No active session');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Response<dynamic>> _getWithAuthRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || _refreshAccessToken == null) {
        rethrow;
      }
      final refreshedToken = await _refreshAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }
      return _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $refreshedToken'}),
      );
    }
  }

  Never _translateError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw FriendsAuthException(e.message);
    }
    throw FriendsLoadException(e.message);
  }

  @override
  Future<List<FriendListItem>> listFriends(FriendListType type) async {
    try {
      final path = switch (type) {
        FriendListType.followers => '$_echoBaseUrl/v1/friends/followers',
        FriendListType.following => '$_echoBaseUrl/v1/friends/following',
      };
      final response = await _getWithAuthRetry(path);
      final raw = response.data as List<dynamic>? ?? const [];
      return raw
          .map((item) => item as Map<String, dynamic>)
          .map(
            (json) => FriendListItem(
              userId: json['user_id'] as String,
              username: json['username'] as String,
              avatarUrl: json['avatar_url'] as String?,
            ),
          )
          .toList();
    } on DioException catch (e) {
      _translateError(e);
    }
  }
}
