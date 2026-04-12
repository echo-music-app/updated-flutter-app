class Track {
  const Track({
    required this.id,
    required this.uri,
    required this.name,
    required this.artistName,
    required this.albumArtUrl,
    required this.durationMs,
  }) : assert(durationMs > 0, 'durationMs must be positive');

  final String id;
  final String uri;
  final String name;
  final String artistName;
  final String albumArtUrl;
  final int durationMs;

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      uri: json['uri'] as String,
      name: json['name'] as String,
      artistName: json['artist_name'] as String,
      albumArtUrl: json['album_art_url'] as String,
      durationMs: json['duration_ms'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uri': uri,
      'name': name,
      'artist_name': artistName,
      'album_art_url': albumArtUrl,
      'duration_ms': durationMs,
    };
  }
}
