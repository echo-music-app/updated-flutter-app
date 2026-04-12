import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/ui/player/track_playback_state.dart';
import 'package:mobile/domain/models/queue.dart';
import 'package:mobile/domain/models/track.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/ui/player/player_screen.dart';
import 'package:mobile/ui/player/player_view_model.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

Widget _wrapWithMaterialApp(Widget child) {
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

// A stub PlayerViewModel that accepts a pre-built controller for tests.
class _StubPlayerViewModel extends PlayerViewModel {
  _StubPlayerViewModel({required PlayerController controller, String? error})
    : super(queueRepository: _NeverQueueRepository()) {
    _stubController = controller;
    _stubError = error;
    _stubLoading = false;
  }

  late PlayerController _stubController;
  String? _stubError;
  bool _stubLoading = false;

  @override
  PlayerController? get controller => _stubController;

  @override
  bool get isLoading => _stubLoading;

  @override
  String? get error => _stubError;
}

// A QueueRepository that never resolves (used by stub ViewModel which never
// calls _init() in a meaningful way since it overrides all getters).
class _NeverQueueRepository implements QueueRepository {
  @override
  Future<Queue> buildQueue() => Completer<Queue>().future;
}

final _testTrack = Track(
  id: '4iV5W9uYEdYUVa79Axb7Rh',
  uri: 'spotify:track:4iV5W9uYEdYUVa79Axb7Rh',
  name: 'Test Song',
  artistName: 'Test Artist',
  albumArtUrl: 'https://i.scdn.co/image/test',
  durationMs: 213000,
);

void main() {
  group('PlayerScreen loading state', () {
    testWidgets('shows CircularProgressIndicator when currentTrack is null', (
      tester,
    ) async {
      final controller = PlayerController(stream: const Stream.empty());
      final viewModel = _StubPlayerViewModel(controller: controller);

      await tester.pumpWidget(
        _wrapWithMaterialApp(PlayerScreen(viewModel: viewModel)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controller.dispose();
    });
  });

  group('PlayerScreen data state', () {
    testWidgets('shows track name and artist when state has currentTrack', (
      tester,
    ) async {
      final streamController = StreamController<TrackPlaybackState>();
      final controller = PlayerController(stream: streamController.stream);
      final viewModel = _StubPlayerViewModel(controller: controller);

      await tester.pumpWidget(
        _wrapWithMaterialApp(PlayerScreen(viewModel: viewModel)),
      );

      streamController.add(
        TrackPlaybackState(
          isPlaying: true,
          positionMs: 0,
          lastPositionTimestamp: DateTime.now(),
          currentTrack: _testTrack,
        ),
      );

      await tester.pump();

      expect(find.text('Test Song'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);

      await streamController.close();
      controller.dispose();
    });
  });

  group('PlayerScreen error state', () {
    testWidgets('shows error message and retry button on error', (
      tester,
    ) async {
      final controller = PlayerController(
        stream: const Stream.empty(),
        initialError: 'Something went wrong',
      );
      final viewModel = _StubPlayerViewModel(controller: controller);

      await tester.pumpWidget(
        _wrapWithMaterialApp(PlayerScreen(viewModel: viewModel)),
      );
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      controller.dispose();
    });
  });
}
