import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/queue.dart';
import 'package:mobile/domain/models/track.dart';

Track _makeTrack(String id) => Track(
  id: id,
  uri: 'spotify:track:$id',
  name: 'Track $id',
  artistName: 'Artist $id',
  albumArtUrl: 'https://example.com/$id.jpg',
  durationMs: 200000,
);

void main() {
  group('Queue state transitions', () {
    test('skipNext advances currentIndex', () {
      final queue = Queue(tracks: [_makeTrack('1'), _makeTrack('2')]);
      expect(queue.currentIndex, 0);
      queue.skipNext();
      expect(queue.currentIndex, 1);
    });

    test('skipPrevious decrements currentIndex', () {
      final queue = Queue(
        tracks: [_makeTrack('1'), _makeTrack('2')],
        currentIndex: 1,
      );
      queue.skipPrevious();
      expect(queue.currentIndex, 0);
    });

    test('hasPrevious is false at index 0', () {
      final queue = Queue(tracks: [_makeTrack('1'), _makeTrack('2')]);
      expect(queue.hasPrevious, isFalse);
    });

    test('hasNext is false at last index', () {
      final queue = Queue(
        tracks: [_makeTrack('1'), _makeTrack('2')],
        currentIndex: 1,
      );
      expect(queue.hasNext, isFalse);
    });

    test('skipNext does nothing at last index', () {
      final queue = Queue(
        tracks: [_makeTrack('1'), _makeTrack('2')],
        currentIndex: 1,
      );
      queue.skipNext();
      expect(queue.currentIndex, 1);
    });

    test('skipPrevious does nothing at index 0', () {
      final queue = Queue(tracks: [_makeTrack('1'), _makeTrack('2')]);
      queue.skipPrevious();
      expect(queue.currentIndex, 0);
    });

    test('currentTrack returns correct track', () {
      final t1 = _makeTrack('1');
      final t2 = _makeTrack('2');
      final queue = Queue(tracks: [t1, t2]);
      expect(queue.currentTrack.id, '1');
      queue.skipNext();
      expect(queue.currentTrack.id, '2');
    });
  });
}
