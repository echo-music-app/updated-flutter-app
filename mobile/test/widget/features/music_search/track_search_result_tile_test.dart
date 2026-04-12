import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/presentation/widgets/track_search_result_tile.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';

Widget _wrap(Widget child) {
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
    home: Scaffold(body: child),
  );
}

TrackSearchResult _track({
  String id = 't1',
  String name = 'Test Track',
  String? artist,
  int? durationMs,
  String? artworkUrl,
}) => TrackSearchResult(
  id: id,
  displayName: name,
  primaryCreatorName: artist,
  durationMs: durationMs,
  artworkUrl: artworkUrl,
  sources: const [],
  relevanceScore: 0.9,
);

void main() {
  group('TrackSearchResultTile — contract', () {
    testWidgets('renders track display name', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackSearchResultTile(track: _track(name: 'Harder, Better'))),
      );
      await tester.pump();
      expect(find.text('Harder, Better'), findsOneWidget);
    });

    testWidgets('renders primary creator name as subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackSearchResultTile(track: _track(artist: 'Daft Punk'))),
      );
      await tester.pump();
      expect(find.text('Daft Punk'), findsOneWidget);
    });

    testWidgets('shows unknown artist fallback when creator absent', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(TrackSearchResultTile(track: _track())));
      await tester.pump();
      expect(find.text('Unknown artist'), findsOneWidget);
    });

    testWidgets('renders duration when durationMs is present', (tester) async {
      await tester.pumpWidget(
        _wrap(TrackSearchResultTile(track: _track(durationMs: 183000))),
      );
      await tester.pump();
      expect(find.text('3:03'), findsOneWidget);
    });

    testWidgets('no duration shown when durationMs is absent', (tester) async {
      await tester.pumpWidget(_wrap(TrackSearchResultTile(track: _track())));
      await tester.pump();
      // Duration text should not appear
      expect(find.text('0:00'), findsNothing);
    });

    testWidgets('shows music note icon when artworkUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(TrackSearchResultTile(track: _track())));
      await tester.pump();
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('has semantics label combining name and artist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TrackSearchResultTile(
            track: _track(name: 'My Track', artist: 'My Artist'),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('My Track, My Artist'), findsOneWidget);
    });
  });

  group('TrackSearchResultTile — dark mode rendering', () {
    testWidgets('renders without overflow in dark mode', (tester) async {
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
          home: Scaffold(
            body: TrackSearchResultTile(
              track: _track(name: 'Dark Track', artist: 'Dark Artist'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TrackSearchResultTile), findsOneWidget);
    });
  });
}
