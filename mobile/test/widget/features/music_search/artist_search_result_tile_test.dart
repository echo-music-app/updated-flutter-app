import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/presentation/widgets/artist_search_result_tile.dart';
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

ArtistSearchResult _artist({
  String id = 'ar1',
  String name = 'Test Artist',
  String? artworkUrl,
}) => ArtistSearchResult(
  id: id,
  displayName: name,
  artworkUrl: artworkUrl,
  sources: const [],
  relevanceScore: 0.7,
);

void main() {
  group('ArtistSearchResultTile — contract', () {
    testWidgets('renders artist display name', (tester) async {
      await tester.pumpWidget(
        _wrap(ArtistSearchResultTile(artist: _artist(name: 'Daft Punk'))),
      );
      await tester.pump();
      expect(find.text('Daft Punk'), findsOneWidget);
    });

    testWidgets('shows person icon when artworkUrl is null', (tester) async {
      await tester.pumpWidget(_wrap(ArtistSearchResultTile(artist: _artist())));
      await tester.pump();
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('has semantics label with artist name', (tester) async {
      await tester.pumpWidget(
        _wrap(ArtistSearchResultTile(artist: _artist(name: 'My Artist'))),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('My Artist'), findsOneWidget);
    });
  });

  group('ArtistSearchResultTile — dark mode rendering', () {
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
            body: ArtistSearchResultTile(artist: _artist(name: 'Dark Artist')),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ArtistSearchResultTile), findsOneWidget);
    });
  });
}
