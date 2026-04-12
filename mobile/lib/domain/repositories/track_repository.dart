import 'package:mobile/domain/models/track.dart';

abstract class TrackRepository {
  Future<Track> getTrack(String trackId);
}
