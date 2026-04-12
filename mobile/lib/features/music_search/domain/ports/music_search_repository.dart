import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';

/// Thrown when the session is expired or unauthorized (HTTP 401).
class MusicSearchAuthException implements Exception {
  const MusicSearchAuthException([this.message]);
  final String? message;
}

/// Thrown for invalid query payloads (HTTP 422).
class MusicSearchValidationException implements Exception {
  const MusicSearchValidationException([this.message]);
  final String? message;
}

/// Thrown when the music search service is unavailable (HTTP 503).
class MusicSearchServiceException implements Exception {
  const MusicSearchServiceException([this.message]);
  final String? message;
}

/// Thrown for transient/unexpected errors (5xx, network).
class MusicSearchTransientException implements Exception {
  const MusicSearchTransientException([this.message]);
  final String? message;
}

abstract interface class MusicSearchRepository {
  /// Executes a music search for [query] against POST /v1/search/music.
  ///
  /// Throws [MusicSearchAuthException] for 401.
  /// Throws [MusicSearchValidationException] for 422.
  /// Throws [MusicSearchServiceException] for 503.
  /// Throws [MusicSearchTransientException] for other network/5xx errors.
  Future<MusicSearchResultGroup> search(String query);
}
