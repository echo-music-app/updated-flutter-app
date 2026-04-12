// T067: SpotifyIframeWidget — loads the Spotify embed iframe for a given
// trackId using flutter_inappwebview. Uses AutomaticKeepAliveClientMixin to
// prevent WebView recreation on parent rebuilds.
//
// The Echo access token is NEVER passed into the WebView context (FR-024).
// Audio will not play due to Widevine EME unavailability (research.md §3).
//
// For widget tests, set SpotifyIframeWidget.testBuilder to a fake widget
// builder; the platform InAppWebView is then bypassed entirely.
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class SpotifyIframeWidget extends StatefulWidget {
  const SpotifyIframeWidget({
    super.key,
    required this.trackId,
    required this.onLoaded,
    required this.onError,
  });

  /// Spotify track ID (e.g. `4iV5W9uYEdYUVa79Axb7Rh`).
  final String trackId;

  /// Fired when the iframe finishes loading (`onLoadStop`).
  final VoidCallback onLoaded;

  /// Fired when the iframe fails to load (`onReceivedError`).
  final VoidCallback onError;

  /// Test override: when non-null, replaces the real InAppWebView in build().
  /// Set in tests to avoid needing a platform channel implementation.
  static Widget Function(
    String trackId,
    VoidCallback onLoaded,
    VoidCallback onError,
  )?
  testBuilder;

  String get _embedUrl => 'https://open.spotify.com/embed/track/$trackId';

  @override
  State<SpotifyIframeWidget> createState() => _SpotifyIframeWidgetState();
}

class _SpotifyIframeWidgetState extends State<SpotifyIframeWidget>
    with AutomaticKeepAliveClientMixin {
  InAppWebViewController? _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(SpotifyIframeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(widget._embedUrl)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    // Test bypass: avoids requiring a platform InAppWebView implementation.
    final testFn = SpotifyIframeWidget.testBuilder;
    if (testFn != null) {
      return testFn(widget.trackId, widget.onLoaded, widget.onError);
    }

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget._embedUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      onLoadStop: (controller, url) => widget.onLoaded(),
      onReceivedError: (controller, request, error) => widget.onError(),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}
