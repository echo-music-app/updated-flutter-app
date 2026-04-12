import 'package:mobile/domain/models/track.dart';

class Queue {
  Queue({required this.tracks, this.currentIndex = 0})
    : assert(tracks.isNotEmpty, 'Queue must have at least one track');

  final List<Track> tracks;
  int currentIndex;

  Track get currentTrack => tracks[currentIndex];

  bool get hasPrevious => currentIndex > 0;

  bool get hasNext => currentIndex < tracks.length - 1;

  void skipNext() {
    if (hasNext) {
      currentIndex++;
    }
  }

  void skipPrevious() {
    if (hasPrevious) {
      currentIndex--;
    }
  }
}
