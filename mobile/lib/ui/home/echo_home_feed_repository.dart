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

  Future<Response<dynamic>> _deleteWithAuthRetry(String path) async {
    try {
      return await _dio.delete(path, options: await _authOptions());
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || _refreshAccessToken == null) {
        rethrow;
      }
      final refreshedToken = await _refreshAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }
      return _dio.delete(
        path,
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

      final followingResponse = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/posts',
        queryParameters: queryParams,
      );
      Map<String, dynamic>? myPostsData;
      try {
        final response = await _getWithAuthRetry(
          '$_echoBaseUrl/v1/me/posts',
          queryParameters: queryParams,
        );
        myPostsData = response.data as Map<String, dynamic>;
      } catch (_) {
        // Keep home feed resilient even if "my posts" endpoint is unavailable.
      }

      final data = followingResponse.data as Map<String, dynamic>;
      final rawFollowingItems = (data['items'] as List<dynamic>? ?? const []);
      final rawMyItems = (myPostsData?['items'] as List<dynamic>? ?? const []);
      final mergedById = <String, Map<String, dynamic>>{};
      for (final item in rawFollowingItems) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id == null) continue;
        mergedById[id] = map;
      }
      for (final item in rawMyItems) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id == null) continue;
        mergedById[id] = map;
      }
      final rawItems = mergedById.values.toList(growable: false);
      final profileMap = await _loadUserProfiles(rawItems);
      final items = rawItems
          .map(
            (item) => _mapPost(
              item,
              profileMap,
              includeFriendsCategory: true,
            ),
          )
          .whereType<HomeFeedPost>()
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return HomeFeedPage(
        items: items,
        pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
        count: items.length,
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
    Map<String, _UserProfile> profileMap, {
    bool includeFriendsCategory = false,
  }) {
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
    final privacy = _mapPrivacy(map['privacy'] as String?);
    final categories = _inferCategories(
      text: text,
      userName: username,
      privacy: privacy,
      includeFriendsCategory: includeFriendsCategory,
    );
    return HomeFeedPost(
      id: id,
      userId: userId,
      userName: username,
      userHandle: '@${username.toLowerCase().replaceAll(' ', '')}',
      userAvatarUrl: profile?.avatarUrl,
      text: text,
      spotifyUrl: spotifyUrl,
      privacy: privacy,
      createdAt: DateTime.parse(createdAtRaw),
      likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      currentUserLiked: map['current_user_liked'] as bool? ?? false,
      categories: categories,
    );
  }

  @override
  Future<HomeFeedPostEngagement> likePost(String postId) async {
    try {
      final response = await _postWithAuthRetry(
        '$_echoBaseUrl/v1/posts/$postId/likes',
      );
      return _mapEngagement(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw HomeFeedAuthException(e.message);
      throw HomeFeedLoadException(e.message);
    }
  }

  @override
  Future<HomeFeedPostEngagement> unlikePost(String postId) async {
    try {
      final response = await _deleteWithAuthRetry(
        '$_echoBaseUrl/v1/posts/$postId/likes',
      );
      return _mapEngagement(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw HomeFeedAuthException(e.message);
      throw HomeFeedLoadException(e.message);
    }
  }

  @override
  Future<List<HomeFeedComment>> listPostComments(String postId) async {
    try {
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/posts/$postId/comments',
      );
      final raw = response.data as List<dynamic>? ?? const [];
      return raw
          .map((item) => item as Map<String, dynamic>)
          .map(
            (json) => HomeFeedComment(
              authorName: json['username'] as String? ?? 'Unknown',
              text: json['content'] as String? ?? '',
              createdAt: DateTime.parse(json['created_at'] as String),
            ),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw HomeFeedAuthException(e.message);
      throw HomeFeedLoadException(e.message);
    }
  }

  @override
  Future<HomeFeedComment> createPostComment(
    String postId,
    String content,
  ) async {
    try {
      final response = await _postWithAuthRetry(
        '$_echoBaseUrl/v1/posts/$postId/comments',
        data: {'content': content},
      );
      final json = response.data as Map<String, dynamic>;
      return HomeFeedComment(
        authorName: json['username'] as String? ?? 'You',
        text: json['content'] as String? ?? content,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw HomeFeedAuthException(e.message);
      throw HomeFeedLoadException(e.message);
    }
  }

  HomeFeedPostEngagement _mapEngagement(Map<String, dynamic> json) {
    return HomeFeedPostEngagement(
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      currentUserLiked: json['current_user_liked'] as bool? ?? false,
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

  static Set<HomeFeedCategory> _inferCategories({
    required String? text,
    required String userName,
    required PostPrivacy privacy,
    required bool includeFriendsCategory,
  }) {
    final corpus = '${text ?? ''} $userName'.toLowerCase();
    final inferred = <HomeFeedCategory>{};

    if (includeFriendsCategory) {
      // Posts loaded from following/friends feed should always be discoverable
      // in the Friends tab.
      inferred.add(HomeFeedCategory.friends);
    }

    if (_containsAny(corpus, const ['budapest', 'buda', 'pest', 'hungary'])) {
      inferred.add(HomeFeedCategory.budapest);
    }
    if (_containsAny(corpus, const [
      'finance',
      'corporate',
      'valuation',
      'cfa',
    ])) {
      inferred.add(HomeFeedCategory.ibsCorporateFinance);
    }
    if (_containsAny(corpus, const [
      'ibs',
      'first year',
      '1st year',
      'freshman',
    ])) {
      inferred.add(HomeFeedCategory.ibsFirstYear);
    }
    if (privacy == PostPrivacy.friendsOnly ||
        _containsAny(corpus, const ['friends', 'buddy', 'group study'])) {
      inferred.add(HomeFeedCategory.friends);
    }

    if (inferred.isEmpty) {
      inferred.add(HomeFeedCategory.ibsFirstYear);
    }
    return inferred;
  }

  static bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) return true;
    }
    return false;
  }
}

class _UserProfile {
  const _UserProfile({required this.username, this.avatarUrl});

  final String username;
  final String? avatarUrl;
}
