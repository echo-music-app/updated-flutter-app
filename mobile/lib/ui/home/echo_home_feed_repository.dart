import 'package:dio/dio.dart';
import 'package:mobile/ui/home/home_feed_repository.dart';
import 'package:mobile/ui/home/home_view_model.dart';

class EchoHomeFeedRepository implements HomeFeedRepository {
  EchoHomeFeedRepository({
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
      throw const HomeFeedAuthException('No active session');
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

  @override
  Future<HomeFeedPage> getFollowingFeed({
    int pageSize = 20,
    String? cursor,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page_size': pageSize};
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }

      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/posts',
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final rawItems = (data['items'] as List<dynamic>? ?? const []);
      final profileMap = await _loadUserProfiles(rawItems);
      final items = rawItems
          .map((item) => _mapPost(item as Map<String, dynamic>, profileMap))
          .whereType<HomeFeedPost>()
          .toList();

      return HomeFeedPage(
        items: items,
        pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
        count: (data['count'] as num?)?.toInt() ?? items.length,
        nextCursor: data['next_cursor'] as String?,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw HomeFeedAuthException(e.message);
      }
      throw HomeFeedLoadException(e.message);
    }
  }

  Future<Map<String, _UserProfile>> _loadUserProfiles(
    List<dynamic> rawItems,
  ) async {
    final userIds = rawItems
        .map((item) => (item as Map<String, dynamic>)['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (userIds.isEmpty) {
      return const {};
    }

    final entries = await Future.wait(
      userIds.map((userId) async {
        try {
          final response = await _getWithAuthRetry(
            '$_echoBaseUrl/v1/users/$userId',
          );
          final data = response.data as Map<String, dynamic>;
          final rawAvatarUrl = data['avatar_url'] as String?;
          final avatarUrl = rawAvatarUrl == null || rawAvatarUrl.isEmpty
              ? null
              : rawAvatarUrl.startsWith('http')
              ? rawAvatarUrl
              : '$_echoBaseUrl$rawAvatarUrl';
          return MapEntry(
            userId,
            _UserProfile(
              username: data['username'] as String? ?? _fallbackName(userId),
              avatarUrl: avatarUrl,
            ),
          );
        } catch (_) {
          return MapEntry(
            userId,
            _UserProfile(username: _fallbackName(userId), avatarUrl: null),
          );
        }
      }),
    );
    return Map<String, _UserProfile>.fromEntries(entries);
  }

  HomeFeedPost? _mapPost(
    Map<String, dynamic> map,
    Map<String, _UserProfile> profileMap,
  ) {
    final id = map['id'] as String?;
    final userId = map['user_id'] as String?;
    final createdAtRaw = map['created_at'] as String?;
    if (id == null || userId == null || createdAtRaw == null) {
      return null;
    }

    final attachments = (map['attachments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    String? text;
    String? spotifyUrl;
    for (final attachment in attachments) {
      final type = attachment['type'] as String? ?? '';
      if (type == 'text' && text == null) {
        final content = attachment['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          text = content.trim();
        }
      } else if (type == 'spotify_link' && spotifyUrl == null) {
        final url = attachment['url'] as String?;
        if (url != null && url.trim().isNotEmpty) {
          spotifyUrl = url.trim();
        }
      }
    }

    if (text == null && spotifyUrl == null) {
      return null;
    }

    final profile = profileMap[userId];
    final username = profile?.username ?? _fallbackName(userId);
    return HomeFeedPost(
      id: id,
      userId: userId,
      userName: username,
      userHandle: '@${username.toLowerCase().replaceAll(' ', '')}',
      userAvatarUrl: profile?.avatarUrl,
      text: text,
      spotifyUrl: spotifyUrl,
      privacy: _mapPrivacy(map['privacy'] as String?),
      createdAt: DateTime.parse(createdAtRaw),
    );
  }

  static PostPrivacy _mapPrivacy(String? value) {
    switch (value) {
      case 'Friends':
        return PostPrivacy.friendsOnly;
      case 'OnlyMe':
        return PostPrivacy.onlyMe;
      case 'Public':
      default:
        return PostPrivacy.public;
    }
  }

  static String _fallbackName(String userId) {
    final short = userId.length <= 8 ? userId : userId.substring(0, 8);
    return 'User $short';
  }
}

class _UserProfile {
  const _UserProfile({required this.username, this.avatarUrl});

  final String username;
  final String? avatarUrl;
}
