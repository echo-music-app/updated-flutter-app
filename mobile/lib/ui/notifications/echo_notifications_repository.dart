import 'package:dio/dio.dart';
import 'package:mobile/ui/notifications/notifications_repository.dart';

class EchoNotificationsRepository implements NotificationsRepository {
  EchoNotificationsRepository({
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
      throw const NotificationsAuthException('No active session');
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

  Never _translateError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw NotificationsAuthException(e.message);
    }
    throw NotificationsLoadException(e.message);
  }

  @override
  Future<List<FollowRequestNotification>> listIncomingFollowRequests() async {
    try {
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/friends/requests/incoming',
      );
      final raw = response.data as List<dynamic>? ?? const [];
      return raw
          .map((item) => item as Map<String, dynamic>)
          .map(
            (json) => FollowRequestNotification(
              requesterUserId: json['requester_user_id'] as String,
              requesterUsername: json['requester_username'] as String,
              requestedAt: DateTime.parse(json['requested_at'] as String),
            ),
          )
          .toList();
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<void> acceptFollowRequest(String requesterUserId) async {
    try {
      await _postWithAuthRetry(
        '$_echoBaseUrl/v1/friends/$requesterUserId/accept',
      );
    } on DioException catch (e) {
      _translateError(e);
    }
  }
}
