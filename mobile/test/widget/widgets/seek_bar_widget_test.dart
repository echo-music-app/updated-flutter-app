import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/ui/player/widgets/seek_bar_widget.dart';

void main() {
  group('SeekBarWidget', () {
    testWidgets('shows elapsed and total time labels', (tester) async {
      final controller = PlayerController(stream: const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekBarWidget(
              controller: controller,
              durationMs: 200000,
              positionMs: 60000,
            ),
          ),
        ),
      );
      await tester.pump();

      // 60000ms = 1:00, 200000ms = 3:20
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('3:20'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('slider value reflects positionMs', (tester) async {
      final controller = PlayerController(stream: const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekBarWidget(
              controller: controller,
              durationMs: 200000,
              positionMs: 100000,
            ),
          ),
        ),
      );
      await tester.pump();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, closeTo(100000, 1));

      controller.dispose();
    });
  });
}
