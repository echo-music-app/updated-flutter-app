import 'package:dio/dio.dart';
import 'package:mobile/domain/models/track.dart';
import 'package:mobile/domain/repositories/track_repository.dart';

class SpotifyTrackRepositoryImpl implements TrackRepository {
  SpotifyTrackRepositoryImpl({
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

  @override
  Future<Track> getTrack(String trackId) async {
    Future<Response<dynamic>> requestWithToken(String token) {
      return _dio.get(
        '$_echoBaseUrl/v1/tracks/$trackId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    final token = await _getAccessToken();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '$_echoBaseUrl/v1/tracks/$trackId'),
        message: 'No active session',
      );
    }

    try {
      final response = await requestWithToken(token);
      return Track.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || _refreshAccessToken == null) {
        rethrow;
      }
      final refreshedToken = await _refreshAccessToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }
      final retryResponse = await requestWithToken(refreshedToken);
      return Track.fromJson(retryResponse.data as Map<String, dynamic>);
    }
  }
}
