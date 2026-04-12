import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';

class SelectSearchResultTypeUseCase {
  const SelectSearchResultTypeUseCase();

  /// Returns the newly selected [requested] type.
  ///
  /// All transitions between the three valid types are permitted.
  SearchResultType call(SearchResultType current, SearchResultType requested) {
    return requested;
  }
}
