import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_header.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/use_cases/resolve_profile_target.dart';

// --- Fake repository ---

class _FakeProfileRepository implements ProfileRepository {
  ProfileHeader? ownProfileResult;
  Object? ownProfileError;

  ProfileHeader? userProfileResult;
  Object? userProfileError;

  ProfilePostsPage? ownPostsResult;
  Object? ownPostsError;

  ProfilePostsPage? userPostsResult;
  Object? userPostsError;

  @override
  Future<ProfileHeader> getOwnProfile() async {
    if (ownProfileError != null) throw ownProfileError!;
    return ownProfileResult!;
  }

  @override
  Future<ProfileHeader> getUserProfile(String userId) async {
    if (userProfileError != null) throw userProfileError!;
    return userProfileResult!;
  }

  @override
  Future<ProfilePostsPage> getOwnPosts({
    int pageSize = 20,
    String? cursor,
  }) async {
    if (ownPostsError != null) throw ownPostsError!;
    return ownPostsResult!;
  }

  @override
  Future<ProfilePostsPage> getUserPosts(
    String userId, {
    int pageSize = 20,
    String? cursor,
  }) async {
    if (userPostsError != null) throw userPostsError!;
    return userPostsResult!;
  }

  @override
  Future<ProfileHeader> updateOwnProfile({String? bio}) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileHeader> uploadOwnAvatar(String filePath) {
    throw UnimplementedError();
  }
}

ProfileHeader _header(String id) =>
    ProfileHeader(id: id, username: 'user_$id', createdAt: DateTime(2026));

ProfilePostsPage _emptyPage() =>
    const ProfilePostsPage(items: [], pageSize: 20, count: 0);

ProfilePostsPage _page(List<String> ids, {String? nextCursor}) =>
    ProfilePostsPage(
      items: ids
          .map(
            (id) => ProfilePostSummary(
              id: id,
              userId: 'u',
              privacy: 'Public',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          )
          .toList(),
      pageSize: 20,
      count: ids.length,
      nextCursor: nextCursor,
    );

void main() {
  group('ResolveProfileTargetUseCase', () {
    const useCase = ResolveProfileTargetUseCase();
    const selfId = 'user-abc';

    test('no userId -> own mode', () {
      final target = useCase.resolve(userId: null, currentUserId: selfId);
      expect(target.mode, ProfileMode.own);
      expect(target.isSelfResolved, false);
    });

    test('empty userId -> own mode', () {
      final target = useCase.resolve(userId: '', currentUserId: selfId);
      expect(target.mode, ProfileMode.own);
    });

    test('userId == currentUserId -> own mode, isSelfResolved=true', () {
      final target = useCase.resolve(userId: selfId, currentUserId: selfId);
      expect(target.mode, ProfileMode.own);
      expect(target.isSelfResolved, true);
    });

    test('userId != currentUserId -> other mode', () {
      final target = useCase.resolve(userId: 'other-id', currentUserId: selfId);
      expect(target.mode, ProfileMode.other);
      expect(target.targetUserId, 'other-id');
      expect(target.isSelfResolved, false);
    });

    test('null currentUserId with userId -> other mode', () {
      final target = useCase.resolve(userId: 'other-id', currentUserId: null);
      expect(target.mode, ProfileMode.other);
    });
  });

  group('LoadProfileHeaderUseCase', () {
    late _FakeProfileRepository repo;
    late LoadProfileHeaderUseCase useCase;

    setUp(() {
      repo = _FakeProfileRepository();
      useCase = LoadProfileHeaderUseCase(repository: repo);
    });

    test('own mode calls getOwnProfile', () async {
      repo.ownProfileResult = _header('1');
      const target = ProfileRouteTarget(mode: ProfileMode.own);
      final result = await useCase(target);
      expect(result.id, '1');
    });

    test('other mode calls getUserProfile', () async {
      repo.userProfileResult = _header('2');
      final target = ProfileRouteTarget(
        mode: ProfileMode.other,
        targetUserId: 'user-2',
      );
      final result = await useCase(target);
      expect(result.id, '2');
    });

    test('other mode throws ProfileAuthException on 401', () async {
      repo.userProfileError = const ProfileAuthException();
      final target = ProfileRouteTarget(
        mode: ProfileMode.other,
        targetUserId: 'user-x',
      );
      expect(() => useCase(target), throwsA(isA<ProfileAuthException>()));
    });

    test('other mode throws ProfileNotFoundException on 404', () async {
      repo.userProfileError = const ProfileNotFoundException();
      final target = ProfileRouteTarget(
        mode: ProfileMode.other,
        targetUserId: 'user-x',
      );
      expect(() => useCase(target), throwsA(isA<ProfileNotFoundException>()));
    });

    test('other mode missing targetUserId throws ProfileLoadException', () {
      const target = ProfileRouteTarget(mode: ProfileMode.other);
      expect(() => useCase(target), throwsA(isA<ProfileLoadException>()));
    });
  });

  group('LoadProfilePostsPageUseCase', () {
    late _FakeProfileRepository repo;
    late LoadProfilePostsPageUseCase useCase;

    setUp(() {
      repo = _FakeProfileRepository();
      useCase = LoadProfilePostsPageUseCase(repository: repo);
    });

    test('own mode calls getOwnPosts', () async {
      repo.ownPostsResult = _emptyPage();
      const target = ProfileRouteTarget(mode: ProfileMode.own);
      final result = await useCase(target);
      expect(result.items, isEmpty);
    });

    test('other mode calls getUserPosts', () async {
      repo.userPostsResult = _page(['p1', 'p2'], nextCursor: 'cursor1');
      final target = ProfileRouteTarget(
        mode: ProfileMode.other,
        targetUserId: 'u2',
      );
      final result = await useCase(target);
      expect(result.items.length, 2);
      expect(result.nextCursor, 'cursor1');
    });

    test('propagates cursor to repository', () async {
      String? capturedCursor;

      // Override to capture cursor
      final captureRepo = _CapturingRepository(
        ownPosts: (cursor) {
          capturedCursor = cursor;
          return _emptyPage();
        },
      );
      final captureUseCase = LoadProfilePostsPageUseCase(
        repository: captureRepo,
      );
      await captureUseCase(
        const ProfileRouteTarget(mode: ProfileMode.own),
        cursor: 'cursor-abc',
      );
      expect(capturedCursor, 'cursor-abc');
    });

    test('other mode missing targetUserId throws ProfileLoadException', () {
      const target = ProfileRouteTarget(mode: ProfileMode.other);
      expect(() => useCase(target), throwsA(isA<ProfileLoadException>()));
    });

    test('propagates auth exception from own posts', () async {
      repo.ownPostsError = const ProfileAuthException();
      const target = ProfileRouteTarget(mode: ProfileMode.own);
      expect(() => useCase(target), throwsA(isA<ProfileAuthException>()));
    });
  });
}

class _CapturingRepository implements ProfileRepository {
  _CapturingRepository({required ProfilePostsPage Function(String?) ownPosts})
    : _ownPosts = ownPosts;

  final ProfilePostsPage Function(String?) _ownPosts;

  @override
  Future<ProfileHeader> getOwnProfile() => throw UnimplementedError();

  @override
  Future<ProfileHeader> getUserProfile(String userId) =>
      throw UnimplementedError();

  @override
  Future<ProfilePostsPage> getOwnPosts({
    int pageSize = 20,
    String? cursor,
  }) async => _ownPosts(cursor);

  @override
  Future<ProfilePostsPage> getUserPosts(
    String userId, {
    int pageSize = 20,
    String? cursor,
  }) => throw UnimplementedError();

  @override
  Future<ProfileHeader> updateOwnProfile({String? bio}) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileHeader> uploadOwnAvatar(String filePath) {
    throw UnimplementedError();
  }
}
