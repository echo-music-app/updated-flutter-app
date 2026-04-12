import 'package:flutter/material.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class SeekBarWidget extends StatelessWidget {
  const SeekBarWidget({
    super.key,
    required this.controller,
    required this.durationMs,
    required this.positionMs,
  });

  final PlayerController controller;
  final int durationMs;
  final int positionMs;

  @override
  Widget build(BuildContext context) {
    final clampedPosition = positionMs.clamp(0, durationMs).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: clampedPosition,
          min: 0,
          max: durationMs.toDouble(),
          onChangeStart: (value) => controller.onDragStart(value.toInt()),
          onChanged: (value) => controller.onDragUpdate(value.toInt()),
          onChangeEnd: (value) => controller.onDragEnd(value.toInt()),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatMs(positionMs)),
              Text(_formatMs(durationMs)),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatMs(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
