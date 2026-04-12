// T065: Widget tests for SpotifyIframeWidget — interface, callbacks, keep-alive.
//
// flutter_inappwebview's InAppWebView requires a platform channel unavailable
// in widget tests. We use SpotifyIframeWidget.testBuilder to inject a fake
// widget, verifying the public interface and callback wiring.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player_webview/widgets/spotify_iframe_widget.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
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
  setUp(() {
    SpotifyIframeWidget.testBuilder = (trackId, onLoaded, onError) =>
        Container(key: ValueKey('iframe-$trackId'), height: 200);
  });

  tearDown(() => SpotifyIframeWidget.testBuilder = null);

  group('SpotifyIframeWidget interface contract', () {
    testWidgets('renders without platform error using testBuilder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SpotifyIframeWidget(
            trackId: '4iV5W9uYEdYUVa79Axb7Rh',
            onLoaded: () {},
            onError: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SpotifyIframeWidget), findsOneWidget);
    });

    testWidgets('onLoaded fires when testBuilder triggers the callback', (
      tester,
    ) async {
      var loadedCalled = false;

      SpotifyIframeWidget.testBuilder = (trackId, onLoaded, onError) {
        // Immediately signal loaded via a post-frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) => onLoaded());
        return Container(key: ValueKey('iframe-$trackId'), height: 200);
      };

      await tester.pumpWidget(
        _wrap(
          SpotifyIframeWidget(
            trackId: 'track001',
            onLoaded: () => loadedCalled = true,
            onError: () {},
          ),
        ),
      );
      await tester.pump(); // trigger post-frame callback

      expect(loadedCalled, isTrue);
    });

    testWidgets('onError fires when testBuilder triggers the callback', (
      tester,
    ) async {
      var errorCalled = false;

      SpotifyIframeWidget.testBuilder = (trackId, onLoaded, onError) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onError());
        return Container(key: ValueKey('iframe-$trackId'), height: 200);
      };

      await tester.pumpWidget(
        _wrap(
          SpotifyIframeWidget(
            trackId: 'track001',
            onLoaded: () {},
            onError: () => errorCalled = true,
          ),
        ),
      );
      await tester.pump();

      expect(errorCalled, isTrue);
    });

    testWidgets('state uses AutomaticKeepAliveClientMixin', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SpotifyIframeWidget(
            trackId: 'test-track',
            onLoaded: () {},
            onError: () {},
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(SpotifyIframeWidget));
      expect(state, isA<AutomaticKeepAliveClientMixin>());
    });
  });
}
