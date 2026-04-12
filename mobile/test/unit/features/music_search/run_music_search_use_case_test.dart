import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';
import 'package:mobile/features/music_search/domain/use_cases/run_music_search.dart';
import 'package:mobile/features/music_search/domain/use_cases/select_search_result_type.dart';

// --- Helpers ---

MusicSearchResultGroup _emptyGroup(String query) => MusicSearchResultGroup(
  query: query,
  limit: 20,
  tracks: const [],
  albums: const [],
  artists: const [],
  summary: const MusicSearchSummary(
    totalCount: 0,
    perTypeCounts: {},
    perSourceCounts: {},
    sourceStatuses: {},
    isPartial: false,
    warnings: [],
  ),
);

class _FakeRepo implements MusicSearchRepository {
  _FakeRepo(this._response);
  final Future<MusicSearchResultGroup> Function(String) _response;

  @override
  Future<MusicSearchResultGroup> search(String query) => _response(query);
}

RunMusicSearchUseCase _makeUseCase(_FakeRepo repo) =>
    RunMusicSearchUseCase(repository: repo);

void main() {
  group('MusicSearchQuery normalization', () {
    test('trims leading and trailing whitespace', () {
      final q = MusicSearchQuery(raw: '  daft punk  ');
      expect(q.trimmed, 'daft punk');
    });

    test('whitespace-only input is invalid', () {
      final q = MusicSearchQuery(raw: '   ');
      expect(q.isValid, false);
    });

    test('empty string is invalid', () {
      final q = MusicSearchQuery(raw: '');
      expect(q.isValid, false);
    });

    test('non-empty trimmed input is valid', () {
      final q = MusicSearchQuery(raw: 'daft punk');
      expect(q.isValid, true);
    });

    test('raw preserves original input', () {
      final q = MusicSearchQuery(raw: '  daft punk  ');
      expect(q.raw, '  daft punk  ');
    });
  });

  group('RunMusicSearchUseCase — validation', () {
    test(
      'throws InvalidSearchQueryException for whitespace-only query',
      () async {
        final uc = _makeUseCase(_FakeRepo((_) async => _emptyGroup('')));
        expect(
          () => uc(MusicSearchQuery(raw: '   ')),
          throwsA(isA<InvalidSearchQueryException>()),
        );
      },
    );

    test('throws InvalidSearchQueryException for empty query', () async {
      final uc = _makeUseCase(_FakeRepo((_) async => _emptyGroup('')));
      expect(
        () => uc(MusicSearchQuery(raw: '')),
        throwsA(isA<InvalidSearchQueryException>()),
      );
    });
  });

  group('RunMusicSearchUseCase — orchestration', () {
    test('forwards trimmed query to repository', () async {
      String? capturedQuery;
      final uc = _makeUseCase(
        _FakeRepo((q) async {
          capturedQuery = q;
          return _emptyGroup(q);
        }),
      );
      await uc(MusicSearchQuery(raw: '  daft punk  '));
      expect(capturedQuery, 'daft punk');
    });

    test('returns repository result unchanged', () async {
      final expected = _emptyGroup('daft punk');
      final uc = _makeUseCase(_FakeRepo((_) async => expected));
      final result = await uc(MusicSearchQuery(raw: 'daft punk'));
      expect(result, same(expected));
    });

    test('propagates MusicSearchAuthException from repository', () async {
      final uc = _makeUseCase(
        _FakeRepo((_) async => throw const MusicSearchAuthException()),
      );
      expect(
        () => uc(MusicSearchQuery(raw: 'test')),
        throwsA(isA<MusicSearchAuthException>()),
      );
    });

    test('propagates MusicSearchTransientException from repository', () async {
      final uc = _makeUseCase(
        _FakeRepo((_) async => throw const MusicSearchTransientException()),
      );
      expect(
        () => uc(MusicSearchQuery(raw: 'test')),
        throwsA(isA<MusicSearchTransientException>()),
      );
    });
  });

  group('SelectSearchResultTypeUseCase', () {
    const uc = SelectSearchResultTypeUseCase();

    test('transitions from tracks to albums', () {
      expect(
        uc(SearchResultType.tracks, SearchResultType.albums),
        SearchResultType.albums,
      );
    });

    test('transitions from albums to artists', () {
      expect(
        uc(SearchResultType.albums, SearchResultType.artists),
        SearchResultType.artists,
      );
    });

    test('allows same-type selection', () {
      expect(
        uc(SearchResultType.tracks, SearchResultType.tracks),
        SearchResultType.tracks,
      );
    });

    test('all valid transitions are permitted', () {
      for (final from in SearchResultType.values) {
        for (final to in SearchResultType.values) {
          expect(uc(from, to), to);
        }
      }
    });
  });
}
