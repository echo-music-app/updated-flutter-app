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

class PlayerWebViewScreen extends StatelessWidget {
  const PlayerWebViewScreen({super.key, required this.viewModel});

  final PlayerWebViewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerTitle)),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.screenState) {
          WebViewScreenState.loading => _buildLoading(),
          WebViewScreenState.error => _buildError(context, l10n),
          WebViewScreenState.data => _buildData(context, l10n),
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
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
    );
  }

  Widget _buildData(BuildContext context, AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          const WebViewLimitationBanner(),
          Expanded(
            child: viewModel.currentTrack == null
                ? const Center(child: CircularProgressIndicator())
                : SpotifyIframeWidget(
                    trackId: viewModel.currentTrack!.id,
                    onLoaded: viewModel.onIframeLoaded,
                    onError: viewModel.onIframeError,
                  ),
          ),
          _buildQueueControls(l10n),
        ],
      ),
    );
  }

  Widget _buildQueueControls(AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: l10n.previousTrack,
            child: IconButton(
              tooltip: l10n.previousTrack,
              icon: const Icon(Icons.skip_previous),
              onPressed: viewModel.hasPrevious ? viewModel.skipPrevious : null,
            ),
          ),
          SizedBox(width: AppSpacing.lg),
          Semantics(
            label: l10n.nextTrack,
            child: IconButton(
              tooltip: l10n.nextTrack,
              icon: const Icon(Icons.skip_next),
              onPressed: viewModel.hasNext ? viewModel.skipNext : null,
            ),
          ),
        ],
      ),
    );
  }
}
