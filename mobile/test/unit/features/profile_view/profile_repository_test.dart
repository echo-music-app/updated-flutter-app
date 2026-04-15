import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile_view/data/repositories/echo_profile_repository.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';

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

const _profileJson = '''
{
  "id": "uid-1",
  "username": "alice",
  "bio": "Producer",
  "preferred_genres": ["house"],
  "is_artist": true,
  "created_at": "2026-03-15T10:00:00.000Z"
}
''';

const _postsJson = '''
{
  "items": [
    {
      "id": "post-1",
      "user_id": "uid-1",
      "privacy": "Public",
      "attachments": [],
      "created_at": "2026-03-16T10:00:00.000Z",
      "updated_at": "2026-03-16T10:00:00.000Z"
    }
  ],
  "count": 1,
  "page_size": 20,
  "next_cursor": null
}
''';

EchoProfileRepository _repo(
  Future<ResponseBody> Function(RequestOptions) handler,
) {
  return EchoProfileRepository(
    echoBaseUrl: 'http://localhost',
    getAccessToken: () async => 'token',
    dio: _mockDio(handler),
  );
}

void main() {
  group('EchoProfileRepository — GET /v1/me', () {
    test('maps 200 response to ProfileHeader', () async {
      final repo = _repo((_) async => _json(_profileJson, 200));
      final header = await repo.getOwnProfile();
      expect(header.id, 'uid-1');
      expect(header.username, 'alice');
      expect(header.bio, 'Producer');
      expect(header.preferredGenres, ['house']);
      expect(header.isArtist, true);
    });

    test('401 throws ProfileAuthException', () async {
      final repo = _repo((_) async => _json('{"detail": "Unauthorized"}', 401));
      expect(() => repo.getOwnProfile(), throwsA(isA<ProfileAuthException>()));
    });

    test('403 throws ProfileLoadException', () async {
      final repo = _repo((_) async => _json('{"detail": "Forbidden"}', 403));
      expect(() => repo.getOwnProfile(), throwsA(isA<ProfileLoadException>()));
    });
  });

  group('EchoProfileRepository — GET /v1/users/{userId}', () {
    test('maps 200 response to ProfileHeader', () async {
      final repo = _repo((_) async => _json(_profileJson, 200));
      final header = await repo.getUserProfile('uid-1');
      expect(header.username, 'alice');
    });

    test('401 throws ProfileAuthException', () async {
      final repo = _repo((_) async => _json('{}', 401));
      expect(
        () => repo.getUserProfile('uid-x'),
        throwsA(isA<ProfileAuthException>()),
      );
    });

    test('404 throws ProfileNotFoundException', () async {
      final repo = _repo((_) async => _json('{}', 404));
      expect(
        () => repo.getUserProfile('uid-x'),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });

    test('422 throws ProfileNotFoundException', () async {
      final repo = _repo((_) async => _json('{}', 422));
      expect(
        () => repo.getUserProfile('not-a-uuid'),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });
  });

  group('EchoProfileRepository — GET /v1/me/posts', () {
    test('maps 200 response to ProfilePostsPage', () async {
      final repo = _repo((_) async => _json(_postsJson, 200));
      final page = await repo.getOwnPosts();
      expect(page.items.length, 1);
      expect(page.items.first.id, 'post-1');
      expect(page.nextCursor, isNull);
    });

    test('passes cursor as query parameter', () async {
      String? capturedCursor;
      final repo = _repo((opts) async {
        capturedCursor = opts.queryParameters['cursor'] as String?;
        return _json(_postsJson, 200);
      });
      await repo.getOwnPosts(cursor: 'cursor-abc');
      expect(capturedCursor, 'cursor-abc');
    });

    test('401 throws ProfileAuthException', () async {
      final repo = _repo((_) async => _json('{}', 401));
      expect(() => repo.getOwnPosts(), throwsA(isA<ProfileAuthException>()));
    });
  });

  group('EchoProfileRepository — GET /v1/user/{userId}/posts', () {
    test('maps 200 response to ProfilePostsPage', () async {
      final repo = _repo((_) async => _json(_postsJson, 200));
      final page = await repo.getUserPosts('uid-1');
      expect(page.count, 1);
    });

    test('401 throws ProfileAuthException', () async {
      final repo = _repo((_) async => _json('{}', 401));
      expect(
        () => repo.getUserPosts('uid-x'),
        throwsA(isA<ProfileAuthException>()),
      );
    });

    test('422 throws ProfileNotFoundException', () async {
      final repo = _repo((_) async => _json('{}', 422));
      expect(
        () => repo.getUserPosts('bad-id'),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });
  });

  group('EchoProfileRepository - follow/status', () {
    test('getFollowStatus maps accepted status', () async {
      final repo = _repo((_) async => _json('{"status":"accepted"}', 200));
      final status = await repo.getFollowStatus('uid-2');
      expect(status, FollowRelationStatus.accepted);
    });

    test('sendFollowRequest succeeds on 200', () async {
      final repo = _repo(
        (_) async => _json('{"status":"pending_outgoing"}', 200),
      );
      await repo.sendFollowRequest('uid-2');
    });

    test('sendFollowRequest 401 throws ProfileAuthException', () async {
      final repo = _repo((_) async => _json('{}', 401));
      expect(
        () => repo.sendFollowRequest('uid-2'),
        throwsA(isA<ProfileAuthException>()),
      );
    });

    test('acceptFollowRequest 401 throws ProfileAuthException', () async {
      final repo = _repo((_) async => _json('{}', 401));
      expect(
        () => repo.acceptFollowRequest('uid-2'),
        throwsA(isA<ProfileAuthException>()),
      );
    });
  });
}
