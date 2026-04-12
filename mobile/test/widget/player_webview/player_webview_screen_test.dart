// T060-T063: Widget tests for PlayerWebViewScreen state machine.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/queue.dart';
import 'package:mobile/domain/models/track.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/domain/repositories/track_repository.dart';
import 'package:mobile/ui/player_webview/player_webview_screen.dart';
import 'package:mobile/ui/player_webview/player_webview_view_model.dart';
import 'package:mobile/ui/player_webview/widgets/spotify_iframe_widget.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

final _track1 = Track(
  id: 'track001',
  uri: 'spotify:track:track001',
  name: 'First Song',
  artistName: 'First Artist',
  albumArtUrl: 'https://i.scdn.co/image/track001',
  durationMs: 200000,
);

final _track2 = Track(
  id: 'track002',
  uri: 'spotify:track:track002',
  name: 'Second Song',
  artistName: 'Second Artist',
  albumArtUrl: 'https://i.scdn.co/image/track002',
  durationMs: 180000,
);

class _FakeQueueRepository implements QueueRepository {
  _FakeQueueRepository(this._tracks, {this.currentIndex = 0});

  final List<Track> _tracks;
  final int currentIndex;

  @override
  Future<Queue> buildQueue() async =>
      Queue(tracks: _tracks, currentIndex: currentIndex);
}

class _FakeTrackRepository implements TrackRepository {
  _FakeTrackRepository(this._fetchTrack);

  final Future<Track> Function(String trackId) _fetchTrack;

  @override
  Future<Track> getTrack(String trackId) => _fetchTrack(trackId);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

PlayerWebViewScreen _buildScreen({
  required List<Track> tracks,
  required Future<Track> Function(String) fetchTrack,
  int currentIndex = 0,
  bool simulateIframeLoaded = false,
  bool simulateIframeError = false,
}) {
  return PlayerWebViewScreen(
    viewModel: PlayerWebViewViewModel.testable(
      queueRepository: _FakeQueueRepository(tracks, currentIndex: currentIndex),
      trackRepository: _FakeTrackRepository(fetchTrack),
      simulateIframeLoaded: simulateIframeLoaded,
      simulateIframeError: simulateIframeError,
    ),
  );
}

void main() {
  setUp(() {
    // Default: iframe renders a plain container (no platform channel).
    SpotifyIframeWidget.testBuilder = (trackId, onLoaded, onError) =>
        Container(key: ValueKey('iframe-$trackId'), height: 200);
  });

  tearDown(() => SpotifyIframeWidget.testBuilder = null);

  // ---------------------------------------------------------------------------
  // T060: loading state
  // ---------------------------------------------------------------------------

  group('PlayerWebViewScreen — T060: loading state', () {
    testWidgets('shows CircularProgressIndicator while fetching metadata', (
      tester,
    ) async {
      // Use a Completer so the fetch never resolves during this test.
      final completer = Completer<Track>();

      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (_) => completer.future,
        simulateIframeLoaded: false,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pump(); // first frame — still loading

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future so the widget disposes cleanly, then pump once
      // (not pumpAndSettle — the circular indicator keeps animating forever).
      completer.complete(_track1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ---------------------------------------------------------------------------
  // T061: data state
  // ---------------------------------------------------------------------------

  group('PlayerWebViewScreen — T061: data state', () {
    testWidgets('shows WebViewLimitationBanner when iframe loaded', (
      tester,
    ) async {
      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (_) async => _track1,
        simulateIframeLoaded: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Audio playback is not available'),
        findsOneWidget,
      );
    });

    testWidgets('shows iframe widget when in data state', (tester) async {
      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (_) async => _track1,
        simulateIframeLoaded: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pumpAndSettle();

      expect(find.byType(SpotifyIframeWidget), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // T062: error state
  // ---------------------------------------------------------------------------

  group('PlayerWebViewScreen — T062: error state', () {
    testWidgets('shows error message and retry button on iframe error', (
      tester,
    ) async {
      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (_) async => _track1,
        simulateIframeLoaded: false,
        simulateIframeError: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Failed to load the Spotify player. Please check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('no stack trace or raw error code shown in error state', (
      tester,
    ) async {
      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (_) async => _track1,
        simulateIframeLoaded: false,
        simulateIframeError: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pumpAndSettle();

      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Error:'), findsNothing);
    });

    testWidgets('retry tap transitions back to loading then resolves', (
      tester,
    ) async {
      // First fetch resolves quickly (→ error via simulateIframeError).
      // Second fetch (after retry) uses a Completer so we can observe loading.
      var callCount = 0;
      final retryCompleter = Completer<Track>();

      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (_) {
          callCount++;
          if (callCount == 1) return Future.value(_track1);
          return retryCompleter.future;
        },
        simulateIframeLoaded: false,
        simulateIframeError: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pump(); // run first fetch
      await tester.pump(
        const Duration(milliseconds: 50),
      ); // settle into error state

      // Now we are in error state — tap Retry.
      await tester.tap(find.text('Retry'));
      await tester.pump(); // setState(loading) fires

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete retry and clean up.
      retryCompleter.complete(_track1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ---------------------------------------------------------------------------
  // T063: queue navigation
  // ---------------------------------------------------------------------------

  group('PlayerWebViewScreen — T063: queue navigation', () {
    testWidgets('prev button disabled when on first track', (tester) async {
      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (id) async => id == 'track001' ? _track1 : _track2,
        currentIndex: 0,
        simulateIframeLoaded: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pumpAndSettle();

      final prevButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Previous track',
        ),
      );
      expect(prevButton.onPressed, isNull);
    });

    testWidgets('next button disabled when on last track', (tester) async {
      final screen = _buildScreen(
        tracks: [_track1, _track2],
        fetchTrack: (id) async => id == 'track001' ? _track1 : _track2,
        currentIndex: 1,
        simulateIframeLoaded: true,
      );

      await tester.pumpWidget(_wrap(screen));
      await tester.pumpAndSettle();

      final nextButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Next track',
        ),
      );
      expect(nextButton.onPressed, isNull);
    });
  });
}
