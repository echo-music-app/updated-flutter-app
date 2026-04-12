import 'package:mobile/domain/models/queue.dart';
import 'package:mobile/domain/models/track.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/domain/repositories/track_repository.dart';

class SpotifyQueueRepositoryImpl implements QueueRepository {
  SpotifyQueueRepositoryImpl({required TrackRepository trackRepository})
    : _trackRepository = trackRepository;

  final TrackRepository _trackRepository;

  /// Hardcoded Spotify track URIs for the PoC queue.
  static const _trackUris = [
    'spotify:track:4iV5W9uYEdYUVa79Axb7Rh',
    'spotify:track:1301WleyT98MSxVHPZCA6M',
    'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
  ];

  /// Build a queue by fetching metadata for each hardcoded track URI.
  @override
  Future<Queue> buildQueue() async {
    final tracks = <Track>[];
    for (final uri in _trackUris) {
      // Extract track ID from URI (spotify:track:<id>)
      final trackId = uri.split(':').last;
      final track = await _trackRepository.getTrack(trackId);
      tracks.add(track);
    }
    return Queue(tracks: tracks);
  }
}
