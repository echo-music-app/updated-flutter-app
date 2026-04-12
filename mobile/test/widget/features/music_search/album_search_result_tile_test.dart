import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/presentation/widgets/album_search_result_tile.dart';
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

AlbumSearchResult _album({
  String id = 'a1',
  String name = 'Test Album',
  String? artist,
  String? artworkUrl,
}) => AlbumSearchResult(
  id: id,
  displayName: name,
  primaryCreatorName: artist,
  artworkUrl: artworkUrl,
  sources: const [],
  relevanceScore: 0.8,
);

void main() {
  group('AlbumSearchResultTile — contract', () {
    testWidgets('renders album display name', (tester) async {
      await tester.pumpWidget(
        _wrap(AlbumSearchResultTile(album: _album(name: 'Homework'))),
      );
      await tester.pump();
      expect(find.text('Homework'), findsOneWidget);
    });

    testWidgets('renders primary creator name as subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(AlbumSearchResultTile(album: _album(artist: 'Daft Punk'))),
      );
      await tester.pump();
      expect(find.text('Daft Punk'), findsOneWidget);
    });

    testWidgets('shows unknown artist fallback when creator absent', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(AlbumSearchResultTile(album: _album())));
      await tester.pump();
      expect(find.text('Unknown artist'), findsOneWidget);
    });

    testWidgets('shows album icon when artworkUrl is null', (tester) async {
      await tester.pumpWidget(_wrap(AlbumSearchResultTile(album: _album())));
      await tester.pump();
      expect(find.byIcon(Icons.album), findsOneWidget);
    });

    testWidgets('has semantics label combining name and artist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AlbumSearchResultTile(
            album: _album(name: 'My Album', artist: 'My Artist'),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('My Album, My Artist'), findsOneWidget);
    });
  });

  group('AlbumSearchResultTile — dark mode rendering', () {
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
            body: AlbumSearchResultTile(
              album: _album(name: 'Dark Album', artist: 'Dark Artist'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AlbumSearchResultTile), findsOneWidget);
    });
  });
}
