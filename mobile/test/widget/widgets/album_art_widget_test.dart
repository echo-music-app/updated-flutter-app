import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player/widgets/album_art_widget.dart';

void main() {
  group('AlbumArtWidget', () {
    testWidgets('shows placeholder icon when url is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AlbumArtWidget(imageUrl: '')),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('shows placeholder icon when url is null-like', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AlbumArtWidget(imageUrl: '')),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });
  });
}
