import 'package:mobile/domain/models/track.dart';

class PlaybackRestrictions {
  const PlaybackRestrictions({
    this.canSkipNext = true,
    this.canSkipPrevious = true,
    this.canSeek = true,
  });

  final bool canSkipNext;
  final bool canSkipPrevious;
  final bool canSeek;
}

class TrackPlaybackState {
  const TrackPlaybackState({
    required this.isPlaying,
    required this.positionMs,
    required this.lastPositionTimestamp,
    this.currentTrack,
    this.restrictions = const PlaybackRestrictions(),
  });

  final bool isPlaying;
  final int positionMs;
  final DateTime lastPositionTimestamp;
  final Track? currentTrack;
  final PlaybackRestrictions restrictions;

  TrackPlaybackState copyWith({
    bool? isPlaying,
    int? positionMs,
    DateTime? lastPositionTimestamp,
    Track? currentTrack,
    PlaybackRestrictions? restrictions,
  }) {
    return TrackPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      lastPositionTimestamp:
          lastPositionTimestamp ?? this.lastPositionTimestamp,
      currentTrack: currentTrack ?? this.currentTrack,
      restrictions: restrictions ?? this.restrictions,
    );
  }
}
