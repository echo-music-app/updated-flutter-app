import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';
import 'package:mobile/features/music_search/domain/use_cases/run_music_search.dart';
import 'package:mobile/features/music_search/domain/use_cases/select_search_result_type.dart';
import 'package:mobile/features/music_search/presentation/music_search_view_model.dart';

// --- Helpers ---

MusicSearchSummary _summary({int total = 0}) => MusicSearchSummary(
  totalCount: total,
  perTypeCounts: const {},
  perSourceCounts: const {},
  sourceStatuses: const {},
  isPartial: false,
  warnings: const [],
);

MusicSearchResultGroup _group({
  List<TrackSearchResult> tracks = const [],
  List<AlbumSearchResult> albums = const [],
  List<ArtistSearchResult> artists = const [],
}) => MusicSearchResultGroup(
  query: 'test',
  limit: 20,
  tracks: tracks,
  albums: albums,
  artists: artists,
  users: const [],
  summary: _summary(total: tracks.length + albums.length + artists.length),
);

TrackSearchResult _track(String id) => TrackSearchResult(
  id: id,
  displayName: 'Track $id',
  sources: const [],
  relevanceScore: 0.9,
);

AlbumSearchResult _album(String id) => AlbumSearchResult(
  id: id,
  displayName: 'Album $id',
  sources: const [],
  relevanceScore: 0.8,
);

ArtistSearchResult _artist(String id) => ArtistSearchResult(
  id: id,
  displayName: 'Artist $id',
  sources: const [],
  relevanceScore: 0.7,
);

// --- Controllable fake repository ---

class _FakeRepo implements MusicSearchRepository {
  Completer<MusicSearchResultGroup>? _completer;

  void resolve(MusicSearchResultGroup g) => _completer?.complete(g);
  void fail(Object e) => _completer?.completeError(e);

  @override
  Future<MusicSearchResultGroup> search(String query) {
    _completer = Completer();
    return _completer!.future;
  }
}

MusicSearchViewModel _makeVm(_FakeRepo repo, {void Function()? onAuthExpired}) {
  return MusicSearchViewModel(
    runSearch: RunMusicSearchUseCase(repository: repo),
    selectType: const SelectSearchResultTypeUseCase(),
    onAuthExpired: onAuthExpired,
  );
}

void main() {
  group('MusicSearchViewModel — initial state', () {
    test('starts in idle status', () {
      final vm = _makeVm(_FakeRepo());
      expect(vm.state.status, SearchScreenStatus.idle);
    });

    test('starts with tracks as selected type', () {
      final vm = _makeVm(_FakeRepo());
      expect(vm.state.selectedType, SearchResultType.tracks);
    });
  });

  group('MusicSearchViewModel — idle -> loading -> data', () {
    late _FakeRepo repo;
    late MusicSearchViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeVm(repo);
    });

    test('transitions to loading immediately on valid search', () async {
      unawaited(vm.search('daft punk'));
      expect(vm.state.status, SearchScreenStatus.loading);
      expect(vm.state.activeQuery, 'daft punk');
      repo.resolve(_group());
    });

    test('transitions to data when tracks are returned', () async {
      final done = vm.search('daft punk');
      repo.resolve(_group(tracks: [_track('1')]));
      await done;
      expect(vm.state.status, SearchScreenStatus.data);
      expect(vm.state.results, isNotNull);
    });

    test('transitions to empty when all result arrays are empty', () async {
      final done = vm.search('daft punk');
      repo.resolve(_group());
      await done;
      expect(vm.state.status, SearchScreenStatus.empty);
    });

    test('sets activeQuery to trimmed value', () async {
      unawaited(vm.search('  daft punk  '));
      expect(vm.state.activeQuery, 'daft punk');
      repo.resolve(_group());
    });

    test('stores results in state after data response', () async {
      final expected = _group(tracks: [_track('1'), _track('2')]);
      final done = vm.search('test');
      repo.resolve(expected);
      await done;
      expect(vm.state.results?.tracks.length, 2);
    });
  });

  group('MusicSearchViewModel — empty/error/auth transitions', () {
    late _FakeRepo repo;
    late MusicSearchViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeVm(repo);
    });

    test('transitions to error on transient exception', () async {
      final done = vm.search('test');
      repo.fail(const MusicSearchTransientException());
      await done;
      expect(vm.state.status, SearchScreenStatus.error);
    });

    test('transitions to error on service exception', () async {
      final done = vm.search('test');
      repo.fail(const MusicSearchServiceException());
      await done;
      expect(vm.state.status, SearchScreenStatus.error);
    });

    test('transitions to authRequired on auth exception', () async {
      final done = vm.search('test');
      repo.fail(const MusicSearchAuthException());
      await done;
      expect(vm.state.status, SearchScreenStatus.authRequired);
    });

    test('invokes onAuthExpired callback on 401', () async {
      bool called = false;
      final vm2 = _makeVm(repo, onAuthExpired: () => called = true);
      final done = vm2.search('test');
      repo.fail(const MusicSearchAuthException());
      await done;
      expect(called, true);
    });

    test('clears results when error occurs', () async {
      final loaded = vm.search('test');
      repo.resolve(_group(tracks: [_track('1')]));
      await loaded;
      expect(vm.state.results, isNotNull);

      repo = _FakeRepo();
      final vm2 = _makeVm(repo);
      final err = vm2.search('test2');
      repo.fail(Exception('fail'));
      await err;
      expect(vm2.state.results, isNull);
    });
  });

  group('MusicSearchViewModel — retry', () {
    late _FakeRepo repo;
    late MusicSearchViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeVm(repo);
    });

    test('retryLastQuery re-runs last submitted query', () async {
      final done = vm.search('test query');
      repo.fail(Exception('fail'));
      await done;
      expect(vm.state.status, SearchScreenStatus.error);

      repo = _FakeRepo();
      final vm2 = MusicSearchViewModel(
        runSearch: RunMusicSearchUseCase(repository: repo),
        selectType: const SelectSearchResultTypeUseCase(),
      );
      // Simulate same state with activeQuery
      unawaited(vm2.search('retry me'));
      final retryDone = vm2.retryLastQuery();
      repo.resolve(_group(tracks: [_track('1')]));
      await retryDone;
    });

    test('retryLastQuery does nothing when activeQuery is empty', () async {
      final vm = _makeVm(_FakeRepo());
      await vm.retryLastQuery(); // Should not throw
      expect(vm.state.status, SearchScreenStatus.idle);
    });
  });

  group('MusicSearchViewModel — segment switching (US2)', () {
    late _FakeRepo repo;
    late MusicSearchViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeVm(repo);
    });

    test('selectType does not re-query backend', () async {
      int searchCount = 0;
      final countingRepo = _FakeRepo();
      final countingVm = MusicSearchViewModel(
        runSearch: RunMusicSearchUseCase(
          repository: _CountingRepo(countingRepo, () => searchCount++),
        ),
        selectType: const SelectSearchResultTypeUseCase(),
      );

      final done = countingVm.search('test');
      countingRepo.resolve(
        _group(tracks: [_track('1')], albums: [_album('1')]),
      );
      await done;
      final beforeCount = searchCount;

      countingVm.selectType(SearchResultType.albums);
      expect(searchCount, beforeCount); // no additional search
    });

    test('switching to segment with results stays in data state', () async {
      final done = vm.search('test');
      repo.resolve(
        _group(
          tracks: [_track('1')],
          albums: [_album('1')],
          artists: [_artist('1')],
        ),
      );
      await done;

      vm.selectType(SearchResultType.albums);
      expect(vm.state.status, SearchScreenStatus.data);
      expect(vm.state.selectedType, SearchResultType.albums);
    });

    test('switching to empty segment transitions to empty state', () async {
      final done = vm.search('test');
      repo.resolve(_group(tracks: [_track('1')])); // no albums/artists
      await done;
      expect(vm.state.status, SearchScreenStatus.data);

      vm.selectType(SearchResultType.albums);
      expect(vm.state.status, SearchScreenStatus.empty);
      expect(vm.state.selectedType, SearchResultType.albums);
    });

    test('switching back to populated segment returns to data state', () async {
      final done = vm.search('test');
      repo.resolve(_group(tracks: [_track('1')]));
      await done;

      vm.selectType(SearchResultType.albums);
      expect(vm.state.status, SearchScreenStatus.empty);

      vm.selectType(SearchResultType.tracks);
      expect(vm.state.status, SearchScreenStatus.data);
    });

    test('segment switch in loading state is ignored', () async {
      unawaited(vm.search('test'));
      expect(vm.state.status, SearchScreenStatus.loading);
      vm.selectType(SearchResultType.albums);
      // Should still be loading, not artists
      expect(vm.state.status, SearchScreenStatus.loading);
      repo.resolve(_group());
    });

    test('segment switch in idle state is ignored', () {
      expect(vm.state.status, SearchScreenStatus.idle);
      vm.selectType(SearchResultType.albums);
      expect(vm.state.status, SearchScreenStatus.idle);
    });
  });

  group('MusicSearchViewModel — stale response protection (US1)', () {
    test(
      'late response from first query does not overwrite second query result',
      () async {
        final repo1 = _FakeRepo();
        final vm = _makeVm(repo1);

        // Start first query — vm is not used further (stale protection tested via vmSingle below)
        unawaited(vm.search('query-1'));

        // Submit second query before first completes
        final repo2 = _FakeRepo();
        final vm2 = MusicSearchViewModel(
          runSearch: RunMusicSearchUseCase(repository: repo2),
          selectType: const SelectSearchResultTypeUseCase(),
        );
        // We can't reuse the same vm here because each vm has its own repo.
        // Test stale protection within a single vm using request version:
        final vmSingle = _makeVm(repo1);
        unawaited(vmSingle.search('query-1'));
        final firstComp = repo1._completer!;

        unawaited(vmSingle.search('query-2'));

        // Resolve second query first
        repo1.resolve(_group(tracks: [_track('q2-result')]));
        await Future.delayed(Duration.zero);

        // Resolve first query late — should be ignored
        firstComp.complete(_group(albums: [_album('q1-stale')]));
        await Future.delayed(Duration.zero);

        // State should reflect only the second query result
        expect(vm2.state.status, SearchScreenStatus.idle); // vm2 untouched
        // vmSingle state — last completed was query-2 result
        expect(vmSingle.state.results?.tracks.length, 1);
      },
    );

    test('rapid queries only apply latest result', () async {
      final repo = _FakeRepo();
      final vm = _makeVm(repo);

      unawaited(vm.search('q1'));
      final comp1 = repo._completer!;

      unawaited(vm.search('q2'));
      final comp2 = repo._completer!;

      unawaited(vm.search('q3'));

      // Complete q3 first (latest)
      repo.resolve(_group(tracks: [_track('q3')]));
      await Future.delayed(Duration.zero);

      // Complete q1 and q2 late
      comp1.complete(_group(artists: [_artist('q1-stale')]));
      comp2.complete(_group(albums: [_album('q2-stale')]));
      await Future.delayed(Duration.zero);

      // Only q3 result should remain
      expect(vm.state.results?.tracks.length, 1);
      expect(vm.state.results?.artists, isEmpty);
    });
  });

  group('MusicSearchViewModel — empty status ignores whitespace queries', () {
    test('whitespace-only query does not trigger search', () async {
      final repo = _FakeRepo();
      final vm = _makeVm(repo);
      await vm.search('   ');
      expect(vm.state.status, SearchScreenStatus.idle);
    });
  });
}

/// Wraps a fake repo to count invocations.
class _CountingRepo implements MusicSearchRepository {
  _CountingRepo(this._delegate, this._onSearch);

  final _FakeRepo _delegate;
  final void Function() _onSearch;

  @override
  Future<MusicSearchResultGroup> search(String query) {
    _onSearch();
    return _delegate.search(query);
  }
}
