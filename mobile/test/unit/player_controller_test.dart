import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/ui/player/track_playback_state.dart';
import 'package:mobile/domain/models/track.dart';

final _testTrack = Track(
  id: 'test-id',
  uri: 'spotify:track:test-id',
  name: 'Test',
  artistName: 'Artist',
  albumArtUrl: 'https://example.com/art.jpg',
  durationMs: 200000,
);

void main() {
  group('PlayerController', () {
    test('updates state when SDK stream emits', () {
      final streamController = StreamController<TrackPlaybackState>();
      final controller = PlayerController(stream: streamController.stream);

      final newState = TrackPlaybackState(
        isPlaying: true,
        positionMs: 5000,
        lastPositionTimestamp: DateTime.now(),
        currentTrack: _testTrack,
      );

      var notified = false;
      controller.addListener(() => notified = true);

      streamController.add(newState);

      // Need to let the async event propagate
      Future.microtask(() {
        expect(controller.state.isPlaying, isTrue);
        expect(controller.state.currentTrack, isNotNull);
        expect(notified, isTrue);

        controller.dispose();
        streamController.close();
      });
    });

    test('clears error on new state', () {
      final streamController = StreamController<TrackPlaybackState>();
      final controller = PlayerController(
        stream: streamController.stream,
        initialError: 'Some error',
      );

      expect(controller.error, 'Some error');

      streamController.add(
        TrackPlaybackState(
          isPlaying: false,
          positionMs: 0,
          lastPositionTimestamp: DateTime.now(),
        ),
      );

      Future.microtask(() {
        expect(controller.error, isNull);
        controller.dispose();
        streamController.close();
      });
    });

    test('surfaces error from stream', () {
      final streamController = StreamController<TrackPlaybackState>();
      final controller = PlayerController(stream: streamController.stream);

      streamController.addError('Premium required');

      Future.microtask(() {
        expect(controller.error, isNotNull);
        controller.dispose();
        streamController.close();
      });
    });

    test('dispose cancels subscription', () {
      final streamController = StreamController<TrackPlaybackState>();
      final controller = PlayerController(stream: streamController.stream);

      controller.dispose();

      // Should not throw even after adding events to a closed controller
      streamController.add(
        TrackPlaybackState(
          isPlaying: false,
          positionMs: 0,
          lastPositionTimestamp: DateTime.now(),
        ),
      );

      streamController.close();
    });
  });
}
