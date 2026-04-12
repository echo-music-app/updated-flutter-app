import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';
import 'package:mobile/features/music_search/domain/use_cases/run_music_search.dart';
import 'package:mobile/features/music_search/domain/use_cases/select_search_result_type.dart';
import 'package:mobile/features/music_search/presentation/music_search_screen.dart';
import 'package:mobile/features/music_search/presentation/music_search_view_model.dart';
import 'package:mobile/features/music_search/presentation/widgets/album_search_result_tile.dart';
import 'package:mobile/features/music_search/presentation/widgets/track_search_result_tile.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';

// --- Helpers ---

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

MusicSearchSummary _summary() => const MusicSearchSummary(
  totalCount: 0,
  perTypeCounts: {},
  perSourceCounts: {},
  sourceStatuses: {},
  isPartial: false,
  warnings: [],
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
  summary: _summary(),
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

class _ImmediateRepo implements MusicSearchRepository {
  _ImmediateRepo(this._response);
  final MusicSearchResultGroup _response;

  @override
  Future<MusicSearchResultGroup> search(String query) async => _response;
}

class _ErrorRepo implements MusicSearchRepository {
  _ErrorRepo(this._error);
  final Object _error;

  @override
  Future<MusicSearchResultGroup> search(String query) async => throw _error;
}

MusicSearchViewModel _makeVm(MusicSearchRepository repo) {
  return MusicSearchViewModel(
    runSearch: RunMusicSearchUseCase(repository: repo),
    selectType: const SelectSearchResultTypeUseCase(),
  );
}

void main() {
  group('MusicSearchScreen — idle state', () {
    testWidgets('shows idle prompt in initial state', (tester) async {
      final vm = _makeVm(_ImmediateRepo(_group()));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await tester.pump();
      expect(find.text('Enter a query to search for music'), findsOneWidget);
    });

    testWidgets('shows search text field', (tester) async {
      final vm = _makeVm(_ImmediateRepo(_group()));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('MusicSearchScreen — query submit (US1)', () {
    testWidgets('tapping search icon submits query', (tester) async {
      String? submitted;
      final repo = _ImmediateRepo(_group(tracks: [_track('1')]));
      final vm = MusicSearchViewModel(
        runSearch: RunMusicSearchUseCase(
          repository: _CaptureRepo(repo, (q) => submitted = q),
        ),
        selectType: const SelectSearchResultTypeUseCase(),
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await tester.enterText(find.byType(TextField), 'daft punk');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(submitted, 'daft punk');
    });

    testWidgets('pressing keyboard search action submits query', (
      tester,
    ) async {
      String? submitted;
      final repo = _ImmediateRepo(_group(tracks: [_track('1')]));
      final vm = MusicSearchViewModel(
        runSearch: RunMusicSearchUseCase(
          repository: _CaptureRepo(repo, (q) => submitted = q),
        ),
        selectType: const SelectSearchResultTypeUseCase(),
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await tester.enterText(find.byType(TextField), 'test query');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submitted, 'test query');
    });
  });

  group('MusicSearchScreen — loading state (US1)', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      final repo = _SlowRepo();
      final vm = _makeVm(repo);
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      unawaited(vm.search('test'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.complete(_group());
      await tester.pumpAndSettle();
    });
  });

  group('MusicSearchScreen — data state with tracks (US1)', () {
    testWidgets('shows SegmentedButton after successful search', (
      tester,
    ) async {
      final vm = _makeVm(_ImmediateRepo(_group(tracks: [_track('1')])));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<SearchResultType>), findsOneWidget);
    });

    testWidgets('renders track tiles in data state', (tester) async {
      final vm = _makeVm(
        _ImmediateRepo(_group(tracks: [_track('1'), _track('2')])),
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(find.byType(TrackSearchResultTile), findsNWidgets(2));
    });
  });

  group('MusicSearchScreen — empty state (US1)', () {
    testWidgets('shows tracks empty message when no results', (tester) async {
      final vm = _makeVm(_ImmediateRepo(_group())); // no results
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('obscure query');
      await tester.pumpAndSettle();
      expect(find.text('No tracks found'), findsOneWidget);
    });
  });

  group('MusicSearchScreen — error state (US1)', () {
    testWidgets('shows error message and retry button on failure', (
      tester,
    ) async {
      final vm = _makeVm(_ErrorRepo(const MusicSearchTransientException()));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(find.text('Search failed. Please try again.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('tapping retry calls retryLastQuery', (tester) async {
      bool retried = false;
      final vm = _StubVm(
        state: const MusicSearchViewState(
          status: SearchScreenStatus.error,
          activeQuery: 'test',
        ),
        onRetry: () => retried = true,
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pump();
      expect(retried, true);
    });
  });

  group('MusicSearchScreen — authRequired state (US1)', () {
    testWidgets('shows auth required message', (tester) async {
      final vm = _makeVm(_ErrorRepo(const MusicSearchAuthException()));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(
        find.text('Your session has expired. Please log in again.'),
        findsOneWidget,
      );
    });
  });

  group('MusicSearchScreen — SegmentedButton (US2)', () {
    testWidgets('shows all three segment options after search', (tester) async {
      final vm = _makeVm(_ImmediateRepo(_group(tracks: [_track('1')])));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
    });

    testWidgets('tapping Albums segment updates selected type', (tester) async {
      final vm = _makeVm(
        _ImmediateRepo(_group(tracks: [_track('1')], albums: [_album('1')])),
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Albums'));
      await tester.pump();
      expect(vm.state.selectedType, SearchResultType.albums);
    });

    testWidgets('only selected segment renders its tile type (US3)', (
      tester,
    ) async {
      final vm = _makeVm(
        _ImmediateRepo(_group(tracks: [_track('1')], albums: [_album('1')])),
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();

      // Default: tracks selected
      expect(find.byType(TrackSearchResultTile), findsOneWidget);
      expect(find.byType(AlbumSearchResultTile), findsNothing);

      // Switch to albums
      await tester.tap(find.text('Albums'));
      await tester.pump();
      expect(find.byType(AlbumSearchResultTile), findsOneWidget);
      expect(find.byType(TrackSearchResultTile), findsNothing);
    });

    testWidgets('per-segment empty message shown when segment has no results', (
      tester,
    ) async {
      final vm = _makeVm(
        _ImmediateRepo(_group(tracks: [_track('1')])), // no albums
      );
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Albums'));
      await tester.pump();
      expect(find.text('No albums found'), findsOneWidget);
    });
  });

  group('MusicSearchScreen — accessibility semantics', () {
    testWidgets('search submit action has semantics label', (tester) async {
      final vm = _makeVm(_ImmediateRepo(_group()));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Search', caseSensitive: false)),
        findsWidgets,
      );
    });

    testWidgets('segmented control has semantics label after search', (
      tester,
    ) async {
      final vm = _makeVm(_ImmediateRepo(_group(tracks: [_track('1')])));
      await tester.pumpWidget(_buildTestApp(MusicSearchScreen(viewModel: vm)));
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Filter results by type'), findsOneWidget);
    });
  });

  group('MusicSearchScreen — dark/light mode rendering', () {
    testWidgets('renders in dark mode without errors', (tester) async {
      final vm = _makeVm(_ImmediateRepo(_group(tracks: [_track('1')])));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MusicSearchScreen(viewModel: vm),
        ),
      );
      await vm.search('test');
      await tester.pumpAndSettle();
      expect(find.byType(MusicSearchScreen), findsOneWidget);
    });
  });
}

// --- Supporting test doubles ---

class _SlowRepo implements MusicSearchRepository {
  Completer<MusicSearchResultGroup>? _completer;

  void complete(MusicSearchResultGroup g) => _completer?.complete(g);

  @override
  Future<MusicSearchResultGroup> search(String query) {
    _completer = Completer();
    return _completer!.future;
  }
}

class _CaptureRepo implements MusicSearchRepository {
  _CaptureRepo(this._delegate, this._capture);
  final MusicSearchRepository _delegate;
  final void Function(String) _capture;

  @override
  Future<MusicSearchResultGroup> search(String query) {
    _capture(query);
    return _delegate.search(query);
  }
}

class _StubVm extends MusicSearchViewModel {
  _StubVm({
    required MusicSearchViewState state,
    required void Function() onRetry,
  }) : _stubState = state,
       _onRetry = onRetry,
       super(
         runSearch: RunMusicSearchUseCase(repository: _NeverRepo()),
         selectType: const SelectSearchResultTypeUseCase(),
       );

  final MusicSearchViewState _stubState;
  final void Function() _onRetry;

  @override
  MusicSearchViewState get state => _stubState;

  @override
  Future<void> retryLastQuery() async => _onRetry();
}

class _NeverRepo implements MusicSearchRepository {
  @override
  Future<MusicSearchResultGroup> search(String query) =>
      throw UnimplementedError();
}
