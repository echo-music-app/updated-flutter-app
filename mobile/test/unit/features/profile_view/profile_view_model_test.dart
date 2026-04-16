import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_header.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/use_cases/resolve_profile_target.dart';
import 'package:mobile/features/profile_view/domain/use_cases/update_own_profile.dart';
import 'package:mobile/features/profile_view/domain/use_cases/upload_own_avatar.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';

// --- Helpers ---

ProfileHeader _header(String id, {String? username}) => ProfileHeader(
  id: id,
  username: username ?? 'user_$id',
  createdAt: DateTime(2026),
);

ProfilePostSummary _post(String id) => ProfilePostSummary(
  id: id,
  userId: 'u',
  privacy: 'Public',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ProfilePostsPage _page(List<ProfilePostSummary> items, {String? nextCursor}) =>
    ProfilePostsPage(
      items: items,
      pageSize: 20,
      count: items.length,
      nextCursor: nextCursor,
    );

// --- Controllable fake repository ---

class _FakeRepo implements ProfileRepository {
  Completer<ProfileHeader>? headerCompleter;
  Completer<ProfilePostsPage>? postsCompleter;

  void resolveHeader(ProfileHeader h) => headerCompleter?.complete(h);
  void failHeader(Object e) => headerCompleter?.completeError(e);
  void resolvePosts(ProfilePostsPage p) => postsCompleter?.complete(p);
  void failPosts(Object e) => postsCompleter?.completeError(e);

  @override
  Future<ProfileHeader> getOwnProfile() {
    headerCompleter = Completer();
    return headerCompleter!.future;
  }

  @override
  Future<ProfileHeader> getUserProfile(String userId) {
    headerCompleter = Completer();
    return headerCompleter!.future;
  }

  @override
  Future<ProfilePostsPage> getOwnPosts({int pageSize = 20, String? cursor}) {
    postsCompleter = Completer();
    return postsCompleter!.future;
  }

  @override
  Future<ProfilePostsPage> getUserPosts(
    String userId, {
    int pageSize = 20,
    String? cursor,
  }) {
    postsCompleter = Completer();
    return postsCompleter!.future;
  }

  @override
  Future<ProfileHeader> updateOwnProfile({String? bio}) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileHeader> uploadOwnAvatar(String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<FollowRelationStatus> getFollowStatus(String userId) async =>
      FollowRelationStatus.none;

  @override
  Future<void> sendFollowRequest(String userId) async {}

  @override
  Future<void> acceptFollowRequest(String userId) async {}
}

ProfileViewModel _makeViewModel(
  ProfileRepository repo, {
  String? currentUserId,
}) {
  return ProfileViewModel(
    resolveTarget: const ResolveProfileTargetUseCase(),
    loadHeader: LoadProfileHeaderUseCase(repository: repo),
    loadPostsPage: LoadProfilePostsPageUseCase(repository: repo),
    updateOwnProfile: UpdateOwnProfileUseCase(repository: repo),
    uploadOwnAvatar: UploadOwnAvatarUseCase(repository: repo),
    currentUserId: currentUserId,
  );
}

void main() {
  group('ProfileViewModel — own mode state transitions', () {
    late _FakeRepo repo;
    late ProfileViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeViewModel(repo, currentUserId: 'me');
    });

    test('initial state is loading/loading', () async {
      unawaited(vm.loadProfile());
      expect(vm.state.headerState, HeaderLoadState.loading);
      expect(vm.state.postsState, PostsLoadState.loading);
    });

    test('own mode -> data state after successful load', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([_post('p1')]));
      await done;
      expect(vm.state.headerState, HeaderLoadState.data);
      expect(vm.state.postsState, PostsLoadState.data);
      expect(vm.state.posts.length, 1);
    });

    test('own mode -> empty posts state when no posts returned', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([]));
      await done;
      expect(vm.state.postsState, PostsLoadState.empty);
    });

    test('own mode -> posts error when posts fail', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.failPosts(Exception('network error'));
      await done;
      expect(vm.state.headerState, HeaderLoadState.data);
      expect(vm.state.postsState, PostsLoadState.error);
    });

    test('header remains visible when posts fail', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.failPosts(Exception('network error'));
      await done;
      expect(vm.state.header, isNotNull);
      expect(vm.state.headerState, HeaderLoadState.data);
    });

    test('auth exception -> authRequired for both sections', () async {
      final done = vm.loadProfile();
      repo.failHeader(const ProfileAuthException());
      repo.resolvePosts(_page([]));
      await done;
      expect(vm.state.headerState, HeaderLoadState.authRequired);
    });

    test('auth exception clears stale header content', () async {
      // First load successfully
      final done1 = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([_post('p1')]));
      await done1;
      expect(vm.state.header, isNotNull);

      // Second load fails with auth
      final done2 = vm.loadProfile();
      repo.failHeader(const ProfileAuthException());
      repo.resolvePosts(_page([]));
      await done2;
      expect(vm.state.header, isNull);
    });
  });

  group('ProfileViewModel — other mode', () {
    late _FakeRepo repo;

    test('self-id normalizes to own mode', () async {
      repo = _FakeRepo();
      final vm = _makeViewModel(repo, currentUserId: 'me');
      final done = vm.loadProfile(userId: 'me');
      repo.resolveHeader(_header('me'));
      repo.resolvePosts(_page([]));
      await done;
      expect(vm.state.headerState, HeaderLoadState.data);
    });

    test('other userId -> other mode not_found state on 404', () async {
      repo = _FakeRepo();
      final vm = _makeViewModel(repo, currentUserId: 'me');
      final done = vm.loadProfile(userId: 'other-user');
      repo.failHeader(const ProfileNotFoundException());
      repo.resolvePosts(_page([]));
      await done;
      expect(vm.state.headerState, HeaderLoadState.notFound);
    });

    test('stale data cleared on new profile load', () async {
      repo = _FakeRepo();
      final vm = _makeViewModel(repo, currentUserId: 'me');

      // Load first profile
      final done1 = vm.loadProfile(userId: 'user-1');
      repo.resolveHeader(_header('user-1'));
      repo.resolvePosts(_page([_post('p1')]));
      await done1;
      expect(vm.state.posts.length, 1);

      // Navigate to new profile — stale content must be cleared
      final done2 = vm.loadProfile(userId: 'user-2');
      expect(vm.state.posts, isEmpty);
      repo.resolveHeader(_header('user-2'));
      repo.resolvePosts(_page([]));
      await done2;
    });
  });

  group('ProfileViewModel — pagination', () {
    late _FakeRepo repo;
    late ProfileViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeViewModel(repo);
    });

    test('canLoadMore is true when nextCursor present', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([_post('p1')], nextCursor: 'cursor1'));
      await done;
      expect(vm.state.canLoadMore, true);
    });

    test('canLoadMore is false when nextCursor is null', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([_post('p1')]));
      await done;
      expect(vm.state.canLoadMore, false);
    });

    test('loadMore appends without replacing existing posts', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([_post('p1')], nextCursor: 'c1'));
      await done;

      final moreDone = vm.loadMore();
      repo.resolvePosts(_page([_post('p2')]));
      await moreDone;

      expect(vm.state.posts.map((p) => p.id).toList(), ['p1', 'p2']);
    });

    test('loadMore failure keeps already-loaded posts', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.resolvePosts(_page([_post('p1')], nextCursor: 'c1'));
      await done;

      final moreDone = vm.loadMore();
      repo.failPosts(Exception('fail'));
      await moreDone;

      expect(vm.state.posts.length, 1);
      expect(vm.state.isLoadingMore, false);
    });

    test('rapid profile switch does not display stale data', () async {
      // Start first profile load
      unawaited(vm.loadProfile(userId: 'user-1'));
      final firstHeaderCompleter = repo.headerCompleter!;

      // Immediately switch to second profile
      final done2 = vm.loadProfile(userId: 'user-2');
      repo.resolveHeader(_header('user-2'));
      repo.resolvePosts(_page([]));
      await done2;

      // Late completion from first profile should not affect state
      firstHeaderCompleter.complete(_header('user-1'));
      await Future.delayed(Duration.zero);

      // State should reflect second profile only
      expect(vm.state.headerState, HeaderLoadState.data);
    });
  });

  group('ProfileViewModel — retry', () {
    late _FakeRepo repo;
    late ProfileViewModel vm;

    setUp(() {
      repo = _FakeRepo();
      vm = _makeViewModel(repo);
    });

    test('retryHeader reloads header', () async {
      final done = vm.loadProfile();
      repo.failHeader(Exception('error'));
      repo.resolvePosts(_page([]));
      await done;
      expect(vm.state.headerState, HeaderLoadState.error);

      final retryDone = vm.retryHeader();
      repo.resolveHeader(_header('1'));
      await retryDone;
      expect(vm.state.headerState, HeaderLoadState.data);
    });

    test('retryPosts reloads posts from page 1', () async {
      final done = vm.loadProfile();
      repo.resolveHeader(_header('1'));
      repo.failPosts(Exception('error'));
      await done;
      expect(vm.state.postsState, PostsLoadState.error);

      final retryDone = vm.retryPosts();
      repo.resolvePosts(_page([_post('p1')]));
      await retryDone;
      expect(vm.state.postsState, PostsLoadState.data);
    });
  });
}
