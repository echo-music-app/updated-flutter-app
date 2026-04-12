import 'package:flutter/material.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isPlaying = controller.state.isPlaying;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: l10n.previousTrack,
              child: IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 40,
                onPressed: controller.hasPrevious
                    ? controller.skipPrevious
                    : null,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Semantics(
              label: isPlaying ? l10n.pauseButton : l10n.playButton,
              child: IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 64,
                onPressed: isPlaying ? controller.pause : controller.play,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Semantics(
              label: l10n.nextTrack,
              child: IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 40,
                onPressed: controller.hasNext ? controller.skipNext : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
