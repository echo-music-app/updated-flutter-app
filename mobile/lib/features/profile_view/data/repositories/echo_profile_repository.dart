import 'package:dio/dio.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';

class EchoProfileRepository implements ProfileRepository {
  EchoProfileRepository({
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
      throw ProfileAuthException('No active session');
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

  Future<Response<dynamic>> _patchWithAuthRetry(
    String path, {
    Object? data,
  }) async {
    try {
      return await _dio.patch(path, data: data, options: await _authOptions());
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || _refreshAccessToken == null) {
        rethrow;
      }
      final refreshedToken = await _refreshAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }
      return _dio.patch(
        path,
        data: data,
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

  ProfileHeader _mapProfile(Map<String, dynamic> json) {
    final rawAvatarUrl = json['avatar_url'] as String?;
    final avatarUrl = rawAvatarUrl == null || rawAvatarUrl.isEmpty
        ? null
        : rawAvatarUrl.startsWith('http')
        ? rawAvatarUrl
        : '$_echoBaseUrl$rawAvatarUrl';
    return ProfileHeader(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: avatarUrl,
      bio: json['bio'] as String?,
      preferredGenres:
          (json['preferred_genres'] as List<dynamic>?)?.cast<String>() ?? [],
      isArtist: (json['is_artist'] as bool?) ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ProfilePostsPage _mapPostsPage(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>).map((item) {
      final map = item as Map<String, dynamic>;
      final attachments =
          (map['attachments'] as List<dynamic>?)?.map((a) {
            final aMap = a as Map<String, dynamic>;
            return PostAttachmentSummary(
              id: aMap['id'] as String,
              type: aMap['type'] as String? ?? '',
              content: aMap['content'] as String?,
              url: aMap['url'] as String?,
            );
          }).toList() ??
          [];
      return ProfilePostSummary(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        privacy: map['privacy'] as String? ?? 'Public',
        attachments: attachments,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    }).toList();
    return ProfilePostsPage(
      items: items,
      pageSize: (json['page_size'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  Never _translateError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) throw ProfileAuthException(e.message);
    if (status == 404) throw ProfileNotFoundException(e.message);
    if (status == 422) throw ProfileNotFoundException(e.message);
    throw ProfileLoadException(e.message);
  }

  @override
  Future<ProfileHeader> getOwnProfile() async {
    try {
      final response = await _getWithAuthRetry('$_echoBaseUrl/v1/me');
      return _mapProfile(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<ProfileHeader> getUserProfile(String userId) async {
    try {
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/users/$userId',
      );
      return _mapProfile(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<ProfilePostsPage> getOwnPosts({
    int pageSize = 20,
    String? cursor,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page_size': pageSize};
      if (cursor != null) queryParams['cursor'] = cursor;
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/me/posts',
        queryParameters: queryParams,
      );
      return _mapPostsPage(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<ProfilePostsPage> getUserPosts(
    String userId, {
    int pageSize = 20,
    String? cursor,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page_size': pageSize};
      if (cursor != null) queryParams['cursor'] = cursor;
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/user/$userId/posts',
        queryParameters: queryParams,
      );
      return _mapPostsPage(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<ProfileHeader> updateOwnProfile({String? bio}) async {
    try {
      final response = await _patchWithAuthRetry(
        '$_echoBaseUrl/v1/me',
        data: bio == null ? const <String, dynamic>{} : {'bio': bio},
      );
      return _mapProfile(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<ProfileHeader> uploadOwnAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _postWithAuthRetry(
        '$_echoBaseUrl/v1/me/avatar',
        data: formData,
      );
      return _mapProfile(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<FollowRelationStatus> getFollowStatus(String userId) async {
    try {
      final response = await _getWithAuthRetry(
        '$_echoBaseUrl/v1/friends/$userId/status',
      );
      final json = response.data as Map<String, dynamic>;
      final status = (json['status'] as String?) ?? 'none';
      switch (status) {
        case 'accepted':
          return FollowRelationStatus.accepted;
        case 'pending_outgoing':
          return FollowRelationStatus.pendingOutgoing;
        case 'pending_incoming':
          return FollowRelationStatus.pendingIncoming;
        case 'self':
          return FollowRelationStatus.self;
        case 'none':
        default:
          return FollowRelationStatus.none;
      }
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<void> sendFollowRequest(String userId) async {
    try {
      await _postWithAuthRetry('$_echoBaseUrl/v1/friends/$userId/request');
    } on DioException catch (e) {
      _translateError(e);
    }
  }

  @override
  Future<void> acceptFollowRequest(String userId) async {
    try {
      await _postWithAuthRetry('$_echoBaseUrl/v1/friends/$userId/accept');
    } on DioException catch (e) {
      _translateError(e);
    }
  }
}
