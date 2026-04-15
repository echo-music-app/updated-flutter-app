import 'package:dio/dio.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';

class EchoMusicSearchRepository implements MusicSearchRepository {
  EchoMusicSearchRepository({
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
      throw MusicSearchAuthException('No active session');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Response<dynamic>> _postWithAuthRetry(
    String path, {
    Map<String, dynamic>? data,
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
    final status = e.response?.statusCode;
    if (status == 401) throw MusicSearchAuthException(e.message);
    if (status == 422) throw MusicSearchValidationException(e.message);
    if (status == 503) throw MusicSearchServiceException(e.message);
    throw MusicSearchTransientException(e.message);
  }

  ResultAttribution _mapAttribution(Map<String, dynamic> json) {
    return ResultAttribution(
      source: json['source'] as String,
      sourceItemId: json['source_item_id'] as String,
      sourceUrl: json['source_url'] as String?,
    );
  }

  List<ResultAttribution> _mapAttributions(dynamic raw) {
    final list = raw as List<dynamic>? ?? [];
    return list.map((a) => _mapAttribution(a as Map<String, dynamic>)).toList();
  }

  TrackSearchResult _mapTrack(Map<String, dynamic> json) {
    return TrackSearchResult(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      primaryCreatorName: json['primary_creator_name'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      playableLink: json['playable_link'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      sources: _mapAttributions(json['sources']),
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  AlbumSearchResult _mapAlbum(Map<String, dynamic> json) {
    return AlbumSearchResult(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      primaryCreatorName: json['primary_creator_name'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      sources: _mapAttributions(json['sources']),
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ArtistSearchResult _mapArtist(Map<String, dynamic> json) {
    return ArtistSearchResult(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      artworkUrl: json['artwork_url'] as String?,
      sources: _mapAttributions(json['sources']),
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  UserSearchResult _mapUser(Map<String, dynamic> json) {
    return UserSearchResult(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  MusicSearchSummary _mapSummary(Map<String, dynamic> json) {
    return MusicSearchSummary(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      perTypeCounts: _castIntMap(json['per_type_counts']),
      perSourceCounts: _castIntMap(json['per_source_counts']),
      sourceStatuses: _castStringMap(json['source_statuses']),
      isPartial: (json['is_partial'] as bool?) ?? false,
      warnings:
          (json['warnings'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, int> _castIntMap(dynamic raw) {
    if (raw == null) return const {};
    return (raw as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
  }

  Map<String, String> _castStringMap(dynamic raw) {
    if (raw == null) return const {};
    return (raw as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
  }

  MusicSearchResultGroup _mapResponse(Map<String, dynamic> json) {
    final tracks = (json['tracks'] as List<dynamic>? ?? [])
        .map((t) => _mapTrack(t as Map<String, dynamic>))
        .toList();
    final albums = (json['albums'] as List<dynamic>? ?? [])
        .map((a) => _mapAlbum(a as Map<String, dynamic>))
        .toList();
    final artists = (json['artists'] as List<dynamic>? ?? [])
        .map((a) => _mapArtist(a as Map<String, dynamic>))
        .toList();
    final summaryRaw = json['summary'] as Map<String, dynamic>? ?? {};
    return MusicSearchResultGroup(
      query: (json['query'] as String?) ?? '',
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      tracks: tracks,
      albums: albums,
      artists: artists,
      users: const [],
      summary: _mapSummary(summaryRaw),
    );
  }

  @override
  Future<MusicSearchResultGroup> search(String query) async {
    try {
      final responses = await Future.wait([
        _postWithAuthRetry('$_echoBaseUrl/v1/search/music', data: {'q': query}),
        _getWithAuthRetry(
          '$_echoBaseUrl/v1/users/search',
          queryParameters: {'q': query, 'limit': 20},
        ),
      ]);
      final musicResponse = responses[0];
      final userResponse = responses[1];
      final musicGroup = _mapResponse(
        musicResponse.data as Map<String, dynamic>,
      );
      final users = (userResponse.data as List<dynamic>)
          .map((u) => _mapUser(u as Map<String, dynamic>))
          .where((u) => u.id.isNotEmpty && u.username.isNotEmpty)
          .toList();

      return MusicSearchResultGroup(
        query: musicGroup.query,
        limit: musicGroup.limit,
        tracks: musicGroup.tracks,
        albums: musicGroup.albums,
        artists: musicGroup.artists,
        users: users,
        summary: musicGroup.summary,
      );
    } on DioException catch (e) {
      _translateError(e);
    }
  }
}
