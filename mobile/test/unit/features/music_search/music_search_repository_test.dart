import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/music_search/data/repositories/echo_music_search_repository.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';

// --- Minimal Dio mock ---

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}

Dio _mockDio(Future<ResponseBody> Function(RequestOptions) handler) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(handler);
  return dio;
}

ResponseBody _json(String body, int status) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

EchoMusicSearchRepository _repo(
  Future<ResponseBody> Function(RequestOptions) handler,
) {
  return EchoMusicSearchRepository(
    echoBaseUrl: 'http://localhost',
    getAccessToken: () async => 'token',
    dio: _mockDio(handler),
  );
}

const _successJson = '''
{
  "query": "daft punk",
  "limit": 20,
  "tracks": [
    {
      "id": "track:1",
      "type": "track",
      "display_name": "Harder, Better, Faster, Stronger",
      "primary_creator_name": "Daft Punk",
      "duration_ms": 224000,
      "playable_link": "https://open.spotify.com/track/abc",
      "artwork_url": "https://img.example.com/art.jpg",
      "sources": [
        {
          "source": "spotify",
          "source_item_id": "spotify:track:abc",
          "source_url": "https://open.spotify.com/track/abc"
        }
      ],
      "relevance_score": 0.97
    }
  ],
  "albums": [],
  "artists": [],
  "summary": {
    "total_count": 1,
    "per_type_counts": {"tracks": 1, "albums": 0, "artists": 0},
    "per_source_counts": {"spotify": 1},
    "source_statuses": {"spotify": "matched"},
    "is_partial": false,
    "warnings": []
  }
}
''';

const _multiTypeJson = '''
{
  "query": "daft punk",
  "limit": 20,
  "tracks": [
    {
      "id": "track:1",
      "display_name": "Around the World",
      "primary_creator_name": "Daft Punk",
      "duration_ms": 429000,
      "sources": [{"source": "spotify", "source_item_id": "sp:t:1"}],
      "relevance_score": 0.9
    }
  ],
  "albums": [
    {
      "id": "album:1",
      "display_name": "Homework",
      "primary_creator_name": "Daft Punk",
      "artwork_url": null,
      "sources": [{"source": "spotify", "source_item_id": "sp:a:1"}],
      "relevance_score": 0.85
    }
  ],
  "artists": [
    {
      "id": "artist:1",
      "display_name": "Daft Punk",
      "artwork_url": null,
      "sources": [{"source": "spotify", "source_item_id": "sp:ar:1"}],
      "relevance_score": 0.99
    }
  ],
  "summary": {
    "total_count": 3,
    "per_type_counts": {"tracks": 1, "albums": 1, "artists": 1},
    "per_source_counts": {"spotify": 3},
    "source_statuses": {"spotify": "matched"},
    "is_partial": false,
    "warnings": []
  }
}
''';

void main() {
  group('EchoMusicSearchRepository — POST /v1/search/music', () {
    test('sends q as POST body field', () async {
      dynamic capturedBody;
      final repo = _repo((opts) async {
        capturedBody = opts.data;
        return _json(_successJson, 200);
      });
      await repo.search('daft punk');
      expect((capturedBody as Map)['q'], 'daft punk');
    });

    test('maps 200 response tracks to TrackSearchResult objects', () async {
      final repo = _repo((_) async => _json(_successJson, 200));
      final result = await repo.search('daft punk');
      expect(result.tracks.length, 1);
      expect(result.tracks.first.id, 'track:1');
      expect(
        result.tracks.first.displayName,
        'Harder, Better, Faster, Stronger',
      );
      expect(result.tracks.first.primaryCreatorName, 'Daft Punk');
      expect(result.tracks.first.durationMs, 224000);
      expect(result.tracks.first.relevanceScore, 0.97);
    });

    test('maps track sources to ResultAttribution objects', () async {
      final repo = _repo((_) async => _json(_successJson, 200));
      final result = await repo.search('daft punk');
      final source = result.tracks.first.sources.first;
      expect(source.source, 'spotify');
      expect(source.sourceItemId, 'spotify:track:abc');
      expect(source.sourceUrl, 'https://open.spotify.com/track/abc');
    });

    test('maps summary fields correctly', () async {
      final repo = _repo((_) async => _json(_successJson, 200));
      final result = await repo.search('daft punk');
      expect(result.summary.totalCount, 1);
      expect(result.summary.isPartial, false);
      expect(result.summary.perTypeCounts['tracks'], 1);
    });

    test('maps all three result types from multi-type response', () async {
      final repo = _repo((_) async => _json(_multiTypeJson, 200));
      final result = await repo.search('daft punk');
      expect(result.tracks.length, 1);
      expect(result.albums.length, 1);
      expect(result.artists.length, 1);
      expect(result.albums.first.displayName, 'Homework');
      expect(result.artists.first.displayName, 'Daft Punk');
    });

    test('missing arrays default to empty lists', () async {
      const minimalJson = '''
      {
        "query": "x",
        "limit": 20,
        "summary": {
          "total_count": 0,
          "per_type_counts": {},
          "per_source_counts": {},
          "source_statuses": {},
          "is_partial": false,
          "warnings": []
        }
      }
      ''';
      final repo = _repo((_) async => _json(minimalJson, 200));
      final result = await repo.search('x');
      expect(result.tracks, isEmpty);
      expect(result.albums, isEmpty);
      expect(result.artists, isEmpty);
    });

    test('401 throws MusicSearchAuthException', () async {
      final repo = _repo((_) async => _json('{"detail": "Unauthorized"}', 401));
      expect(
        () => repo.search('daft punk'),
        throwsA(isA<MusicSearchAuthException>()),
      );
    });

    test('422 throws MusicSearchValidationException', () async {
      final repo = _repo(
        (_) async => _json('{"detail": "Unprocessable"}', 422),
      );
      expect(
        () => repo.search(''),
        throwsA(isA<MusicSearchValidationException>()),
      );
    });

    test('503 throws MusicSearchServiceException', () async {
      final repo = _repo(
        (_) async => _json('{"detail": "Service unavailable"}', 503),
      );
      expect(
        () => repo.search('daft punk'),
        throwsA(isA<MusicSearchServiceException>()),
      );
    });

    test('5xx throws MusicSearchTransientException', () async {
      final repo = _repo((_) async => _json('{"detail": "Server error"}', 500));
      expect(
        () => repo.search('daft punk'),
        throwsA(isA<MusicSearchTransientException>()),
      );
    });
  });

  group('EchoMusicSearchRepository — US3 per-type object mapping', () {
    test('track maps optional fields to null when absent', () async {
      const minimalTrack = '''
      {
        "query": "x", "limit": 20,
        "tracks": [
          {
            "id": "t:1",
            "display_name": "Track One",
            "sources": [{"source": "spotify", "source_item_id": "sp:t:1"}],
            "relevance_score": 0.5
          }
        ],
        "albums": [], "artists": [],
        "summary": {"total_count": 1, "per_type_counts": {}, "per_source_counts": {}, "source_statuses": {}, "is_partial": false, "warnings": []}
      }
      ''';
      final repo = _repo((_) async => _json(minimalTrack, 200));
      final result = await repo.search('x');
      expect(result.tracks.first.primaryCreatorName, isNull);
      expect(result.tracks.first.durationMs, isNull);
      expect(result.tracks.first.artworkUrl, isNull);
    });

    test('album maps to distinct AlbumSearchResult type', () async {
      final repo = _repo((_) async => _json(_multiTypeJson, 200));
      final result = await repo.search('daft punk');
      expect(result.albums.first.id, 'album:1');
      expect(result.albums.first.primaryCreatorName, 'Daft Punk');
    });

    test('artist maps to distinct ArtistSearchResult type', () async {
      final repo = _repo((_) async => _json(_multiTypeJson, 200));
      final result = await repo.search('daft punk');
      expect(result.artists.first.id, 'artist:1');
    });
  });
}
