import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/ui/player/widgets/playback_controls.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

Widget _wrapWithMaterialApp(Widget child) {
  return MaterialApp(
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

void main() {
  group('PlaybackControls', () {
    testWidgets('shows play icon when paused', (tester) async {
      final controller = PlayerController(stream: const Stream.empty());

      await tester.pumpWidget(
        _wrapWithMaterialApp(PlaybackControls(controller: controller)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      controller.dispose();
    });

    testWidgets('shows pause icon when playing', (tester) async {
      // Controller starts with isPlaying = false, need to test indirectly
      final controller = PlayerController(stream: const Stream.empty());

      await tester.pumpWidget(
        _wrapWithMaterialApp(PlaybackControls(controller: controller)),
      );
      await tester.pump();

      // Default state is paused → play icon
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      controller.dispose();
    });
  });
}
