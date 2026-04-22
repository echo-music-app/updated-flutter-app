import 'package:flutter/material.dart';
import 'package:mobile/ui/player/player_view_model.dart';
import 'package:mobile/ui/player/widgets/album_art_widget.dart';
import 'package:mobile/ui/player/widgets/playback_controls.dart';
import 'package:mobile/ui/player/widgets/seek_bar_widget.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.viewModel});

  final PlayerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerTitle)),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.isLoading) {
            return _buildLoadingState(l10n);
          }
          if (viewModel.error != null) {
            return _buildErrorState(context, l10n);
          }
          final controller = viewModel.controller!;
          return ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.error != null) {
                return _buildControllerErrorState(
                  context,
                  l10n,
                  controller.error!,
                );
              }
              if (controller.state.currentTrack == null) {
                return _buildLoadingState(l10n);
              }
              return _buildDataState(context, l10n, controller);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text(l10n.loadingTracks),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(viewModel.error!, textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.md),
            Semantics(
              label: l10n.retryButton,
              child: ElevatedButton(
                onPressed: viewModel.retry,
                child: Text(l10n.retryButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControllerErrorState(
    BuildContext context,
    AppLocalizations l10n,
    String error,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.md),
            Semantics(
              label: l10n.retryButton,
              child: ElevatedButton(
                onPressed: viewModel.controller!.retry,
                child: Text(l10n.retryButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataState(
    BuildContext context,
    AppLocalizations l10n,
    controller,
  ) {
    final track = controller.state.currentTrack!;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AlbumArtWidget(imageUrl: track.albumArtUrl),
              SizedBox(height: AppSpacing.lg),
              Text(
                track.name,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                track.artistName,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg),
              SeekBarWidget(
                controller: controller,
                durationMs: track.durationMs,
                positionMs: controller.displayPositionMs,
              ),
              SizedBox(height: AppSpacing.md),
              PlaybackControls(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}
