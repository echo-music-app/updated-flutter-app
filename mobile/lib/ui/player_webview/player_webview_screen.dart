// T068: PlayerWebViewScreen — Spotify iframe embed player screen at /player-webview.
//
// State machine: loading → data → error (retry → loading).
// No JS bridge is used; Dart interacts with the iframe only by loading/reloading URLs.
// The Echo access token is never passed into the WebView context (FR-024).
// Audio will not play in WebView (Widevine EME unavailable); WebViewLimitationBanner
// is always visible in the data state (FR-025).
import 'package:flutter/material.dart';
import 'package:mobile/ui/player_webview/player_webview_view_model.dart';
import 'package:mobile/ui/player_webview/widgets/spotify_iframe_widget.dart';
import 'package:mobile/ui/player_webview/widgets/webview_limitation_banner.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/core/widgets/trend_surfaces.dart';

class PlayerWebViewScreen extends StatelessWidget {
  const PlayerWebViewScreen({super.key, required this.viewModel});

  final PlayerWebViewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const AppTopNavLeading(),
        title: Text(l10n.playerTitle),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: appTrendBackground(context),
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => switch (viewModel.screenState) {
            WebViewScreenState.loading => _buildLoading(context),
            WebViewScreenState.error => _buildError(context, l10n),
            WebViewScreenState.data => _buildData(context, l10n),
          },
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: TrendPanel(
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: TrendPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.webViewPlayerLoadError, textAlign: TextAlign.center),
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
      ),
    );
  }

  Widget _buildData(BuildContext context, AppLocalizations l10n) {
    final currentTrack = viewModel.currentTrack;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          children: [
            TrendPanel(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.album_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentTrack?.name ?? 'Preparing track...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentTrack?.artistName ?? 'Spotify',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const WebViewLimitationBanner(),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: TrendPanel(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: currentTrack == null
                      ? const Center(child: CircularProgressIndicator())
                      : SpotifyIframeWidget(
                          trackId: currentTrack.id,
                          onLoaded: viewModel.onIframeLoaded,
                          onError: viewModel.onIframeError,
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildQueueControls(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueControls(BuildContext context, AppLocalizations l10n) {
    return TrendPanel(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: l10n.previousTrack,
              child: FilledButton.tonalIcon(
                onPressed: viewModel.hasPrevious
                    ? viewModel.skipPrevious
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
                label: Text(l10n.previousTrack),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: l10n.nextTrack,
              child: FilledButton.tonalIcon(
                onPressed: viewModel.hasNext ? viewModel.skipNext : null,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(l10n.nextTrack),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
