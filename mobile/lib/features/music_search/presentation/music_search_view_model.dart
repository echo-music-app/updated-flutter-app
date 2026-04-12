import 'package:flutter/foundation.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';
import 'package:mobile/features/music_search/domain/use_cases/run_music_search.dart';
import 'package:mobile/features/music_search/domain/use_cases/select_search_result_type.dart';

class MusicSearchViewModel extends ChangeNotifier {
  MusicSearchViewModel({
    required RunMusicSearchUseCase runSearch,
    required SelectSearchResultTypeUseCase selectType,
    void Function()? onAuthExpired,
  }) : _runSearch = runSearch,
       _selectType = selectType,
       _onAuthExpired = onAuthExpired;

  final RunMusicSearchUseCase _runSearch;
  final SelectSearchResultTypeUseCase _selectType;
  final void Function()? _onAuthExpired;

  MusicSearchViewState _state = const MusicSearchViewState();
  MusicSearchViewState get state => _state;

  int _requestVersion = 0;

  void _emit(MusicSearchViewState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> search(String rawQuery) async {
    final query = MusicSearchQuery(raw: rawQuery);
    if (!query.isValid) return;

    final version = ++_requestVersion;
    _emit(
      _state.copyWith(
        status: SearchScreenStatus.loading,
        activeQuery: query.trimmed,
        clearResults: true,
        clearError: true,
      ),
    );

    try {
      final results = await _runSearch(query);
      if (version != _requestVersion) return;

      final visibleCount = _countForType(results, _state.selectedType);
      _emit(
        _state.copyWith(
          status: visibleCount > 0
              ? SearchScreenStatus.data
              : SearchScreenStatus.empty,
          results: results,
          clearError: true,
        ),
      );
    } on MusicSearchAuthException {
      if (version != _requestVersion) return;
      _onAuthExpired?.call();
      _emit(
        MusicSearchViewState(
          status: SearchScreenStatus.authRequired,
          selectedType: _state.selectedType,
        ),
      );
    } on MusicSearchValidationException {
      if (version != _requestVersion) return;
      _emit(
        _state.copyWith(
          status: SearchScreenStatus.error,
          clearResults: true,
          errorMessageKey: 'searchValidationErrorMessage',
        ),
      );
    } on MusicSearchServiceException {
      if (version != _requestVersion) return;
      _emit(
        _state.copyWith(
          status: SearchScreenStatus.error,
          clearResults: true,
          errorMessageKey: 'searchServiceUnavailableMessage',
        ),
      );
    } catch (_) {
      if (version != _requestVersion) return;
      _emit(
        _state.copyWith(
          status: SearchScreenStatus.error,
          clearResults: true,
          errorMessageKey: 'searchErrorMessage',
        ),
      );
    }
  }

  void selectType(SearchResultType type) {
    final status = _state.status;
    if (status != SearchScreenStatus.data &&
        status != SearchScreenStatus.empty) {
      return;
    }
    final results = _state.results;
    if (results == null) return;

    final selected = _selectType(_state.selectedType, type);
    final visibleCount = _countForType(results, selected);
    _emit(
      _state.copyWith(
        selectedType: selected,
        status: visibleCount > 0
            ? SearchScreenStatus.data
            : SearchScreenStatus.empty,
      ),
    );
  }

  Future<void> retryLastQuery() async {
    final query = _state.activeQuery;
    if (query.isEmpty) return;
    await search(query);
  }

  int _countForType(MusicSearchResultGroup results, SearchResultType type) {
    switch (type) {
      case SearchResultType.tracks:
        return results.tracks.length;
      case SearchResultType.albums:
        return results.albums.length;
      case SearchResultType.artists:
        return results.artists.length;
    }
  }
}
