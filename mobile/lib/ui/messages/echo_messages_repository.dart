import 'package:dio/dio.dart';
import 'package:mobile/ui/messages/messages_repository.dart';

class EchoMessagesRepository implements MessagesRepository {
  EchoMessagesRepository({
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
      throw const MessagesAuthException('No active session');
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
    final status = e.response?.statusCode;
    if (status == 401) {
      throw MessagesAuthException(e.message);
    }
    if (status == 403) {
      throw MessagesPermissionException(
        e.response?.data is Map<String, dynamic>
            ? (e.response?.data['detail'] as String?)
            : e.message,
      );
    }
    throw MessagesLoadException(e.message);
  }

  @override
  Future<List<MessageThreadSummary>> listThreads() async {
    try {
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/messages/threads',
      );
      final raw = response.data as List<dynamic>? ?? const [];
      return raw
          .map((item) => item as Map<String, dynamic>)
          .map(
            (json) => MessageThreadSummary(
              userId: json['user_id'] as String,
              username: json['username'] as String,
              lastMessagePreview: json['last_message_preview'] as String,
              lastMessageAt: DateTime.parse(json['last_message_at'] as String),
            ),
          )
          .toList();
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<DirectMessageThread> getConversation(String userId) async {
    try {
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/messages/$userId',
      );
      final json = response.data as Map<String, dynamic>;
      final rawItems = json['items'] as List<dynamic>? ?? const [];
      return DirectMessageThread(
        targetUserId: json['target_user_id'] as String,
        targetUsername: json['target_username'] as String,
        items: rawItems
            .map((item) => item as Map<String, dynamic>)
            .map(
              (item) => DirectMessage(
                id: item['id'] as String,
                senderUserId: item['sender_user_id'] as String,
                senderUsername: item['sender_username'] as String,
                text: item['text'] as String,
                createdAt: DateTime.parse(item['created_at'] as String),
                isMine: item['is_mine'] as bool? ?? false,
              ),
            )
            .toList(),
      );
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<DirectMessage> sendMessage(String userId, String text) async {
    try {
      final response = await _postWithAuthRetry(
        '$_echoBaseUrl/v1/messages/$userId',
        data: {'text': text},
      );
      final item = response.data as Map<String, dynamic>;
      return DirectMessage(
        id: item['id'] as String,
        senderUserId: item['sender_user_id'] as String,
        senderUsername: item['sender_username'] as String,
        text: item['text'] as String,
        createdAt: DateTime.parse(item['created_at'] as String),
        isMine: item['is_mine'] as bool? ?? false,
      );
    } on DioException catch (e) {
      _translateError(e);
    }
  }
}
