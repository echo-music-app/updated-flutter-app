import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/ui/player/track_playback_state.dart';
import 'package:mobile/domain/models/queue.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    required Stream<TrackPlaybackState> stream,
    String? initialError,
    Queue? queue,
  }) : _error = initialError,
       _queue = queue,
       _state = TrackPlaybackState(
         isPlaying: false,
         positionMs: 0,
         lastPositionTimestamp: DateTime.now(),
       ) {
    _subscription = stream.listen(
      _onStateChanged,
      onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  TrackPlaybackState _state;
  String? _error;
  StreamSubscription<TrackPlaybackState>? _subscription;
  VoidCallback? _onRetry;
  bool _isDragging = false;
  int _dragPositionMs = 0;
  Queue? _queue;

  /// Callback invoked when skip changes the track and metadata needs refresh.
  Future<void> Function(String trackId)? onTrackChanged;

  TrackPlaybackState get state => _state;
  String? get error => _error;
  bool get isDragging => _isDragging;

  bool get hasPrevious => _queue?.hasPrevious ?? false;
  bool get hasNext => _queue?.hasNext ?? false;

  /// The current position to display, considering drag state.
  int get displayPositionMs =>
      _isDragging ? _dragPositionMs : _state.positionMs;

  set onRetry(VoidCallback? callback) => _onRetry = callback;
  set queue(Queue? q) {
    _queue = q;
    notifyListeners();
  }

  void _onStateChanged(TrackPlaybackState newState) {
    // Detect track-end: isPaused + positionMs == 0 on non-user seek
    if (!_isDragging &&
        !newState.isPlaying &&
        newState.positionMs == 0 &&
        _state.isPlaying) {
      // Track ended — reset
      _state = newState.copyWith(isPlaying: false, positionMs: 0);
      _error = null;
      notifyListeners();
      return;
    }

    if (_isDragging) {
      _state = newState.copyWith(positionMs: _dragPositionMs);
    } else {
      _state = newState;
    }
    _error = null;
    notifyListeners();
  }

  void retry() {
    _error = null;
    notifyListeners();
    _onRetry?.call();
  }

  Future<void> play() async {
    // Wired to SpotifySdk.resume() in production
  }

  Future<void> pause() async {
    // Wired to SpotifySdk.pause() in production
  }

  void onDragStart(int positionMs) {
    _isDragging = true;
    _dragPositionMs = positionMs;
    notifyListeners();
  }

  void onDragUpdate(int positionMs) {
    _dragPositionMs = positionMs;
    notifyListeners();
  }

  Future<void> onDragEnd(int positionMs) async {
    _dragPositionMs = positionMs;
    await seekTo(positionMs);
  }

  Future<void> seekTo(int positionMs) async {
    _state = _state.copyWith(positionMs: positionMs);
    notifyListeners();
    // In production, calls SpotifySdk.seekToRelativePosition(positionMs)
    _isDragging = false;
  }

  Future<void> skipNext() async {
    if (_queue == null || !_queue!.hasNext) return;
    _queue!.skipNext();
    _state = _state.copyWith(positionMs: 0);
    notifyListeners();
    // Fetch updated track metadata
    final trackId = _queue!.currentTrack.id;
    await onTrackChanged?.call(trackId);
    // In production, also calls SpotifySdk.skipNext()
  }

  Future<void> skipPrevious() async {
    if (_queue == null || !_queue!.hasPrevious) return;
    _queue!.skipPrevious();
    _state = _state.copyWith(positionMs: 0);
    notifyListeners();
    // Fetch updated track metadata
    final trackId = _queue!.currentTrack.id;
    await onTrackChanged?.call(trackId);
    // In production, also calls SpotifySdk.skipPrevious()
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
