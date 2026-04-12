import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';

/// Thrown when the submitted query is invalid (empty after trimming).
class InvalidSearchQueryException implements Exception {
  const InvalidSearchQueryException([this.message]);
  final String? message;
}

class RunMusicSearchUseCase {
  const RunMusicSearchUseCase({required this.repository});

  final MusicSearchRepository repository;

  /// Validates [query] and delegates to [repository].
  ///
  /// Throws [InvalidSearchQueryException] when query is empty after trim.
  /// Propagates repository exceptions unchanged.
  Future<MusicSearchResultGroup> call(MusicSearchQuery query) async {
    if (!query.isValid) {
      throw const InvalidSearchQueryException('Query must not be empty');
    }
    return repository.search(query.trimmed);
  }
}
