import 'package:flutter/foundation.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_header.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/use_cases/resolve_profile_target.dart';

enum HeaderLoadState { loading, data, empty, error, notFound, authRequired }

enum PostsLoadState { loading, data, empty, error, authRequired }

class ProfileViewState {
  const ProfileViewState({
    this.headerState = HeaderLoadState.loading,
    this.header,
    this.postsState = PostsLoadState.loading,
    this.posts = const [],
    this.isLoadingMore = false,
    this.canLoadMore = false,
  });

  final HeaderLoadState headerState;
  final ProfileHeader? header;
  final PostsLoadState postsState;
  final List<ProfilePostSummary> posts;
  final bool isLoadingMore;
  final bool canLoadMore;

  ProfileViewState copyWith({
    HeaderLoadState? headerState,
    ProfileHeader? header,
    bool clearHeader = false,
    PostsLoadState? postsState,
    List<ProfilePostSummary>? posts,
    bool? isLoadingMore,
    bool? canLoadMore,
  }) {
    return ProfileViewState(
      headerState: headerState ?? this.headerState,
      header: clearHeader ? null : (header ?? this.header),
      postsState: postsState ?? this.postsState,
      posts: posts ?? this.posts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      canLoadMore: canLoadMore ?? this.canLoadMore,
    );
  }
}

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required ResolveProfileTargetUseCase resolveTarget,
    required LoadProfileHeaderUseCase loadHeader,
    required LoadProfilePostsPageUseCase loadPostsPage,
    required String? currentUserId,
  }) : _resolveTarget = resolveTarget,
       _loadHeader = loadHeader,
       _loadPostsPage = loadPostsPage,
       _currentUserId = currentUserId;

  final ResolveProfileTargetUseCase _resolveTarget;
  final LoadProfileHeaderUseCase _loadHeader;
  final LoadProfilePostsPageUseCase _loadPostsPage;
  final String? _currentUserId;

  ProfileViewState _state = const ProfileViewState();
  ProfileViewState get state => _state;

  ProfileRouteTarget? _target;
  String? _nextCursor;

  void _emit(ProfileViewState s) {
    _state = s;
    notifyListeners();
  }

  /// Call when navigating to a profile. Clears stale content.
  Future<void> loadProfile({String? userId}) async {
    _target = _resolveTarget.resolve(
      userId: userId,
      currentUserId: _currentUserId,
    );
    _nextCursor = null;
    _emit(const ProfileViewState()); // reset to loading/loading

    await Future.wait([_fetchHeader(), _fetchFirstPostsPage()]);
  }

  Future<void> _fetchHeader() async {
    try {
      final header = await _loadHeader(_target!);
      _emit(_state.copyWith(headerState: HeaderLoadState.data, header: header));
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.authRequired,
          clearHeader: true,
          postsState: PostsLoadState.authRequired,
          posts: [],
        ),
      );
    } on ProfileNotFoundException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.notFound,
          postsState: PostsLoadState.empty,
          posts: [],
        ),
      );
    } catch (_) {
      _emit(_state.copyWith(headerState: HeaderLoadState.error));
    }
  }

  Future<void> _fetchFirstPostsPage() async {
    try {
      final page = await _loadPostsPage(_target!, pageSize: 20, cursor: null);
      _nextCursor = page.nextCursor;
      final postsState = page.items.isEmpty
          ? PostsLoadState.empty
          : PostsLoadState.data;
      _emit(
        _state.copyWith(
          postsState: postsState,
          posts: page.items,
          canLoadMore: page.nextCursor != null,
        ),
      );
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          postsState: PostsLoadState.authRequired,
          posts: [],
          canLoadMore: false,
        ),
      );
    } catch (_) {
      _emit(
        _state.copyWith(
          postsState: PostsLoadState.error,
          posts: [],
          canLoadMore: false,
        ),
      );
    }
  }

  Future<void> retryHeader() async {
    if (_target == null) return;
    _emit(_state.copyWith(headerState: HeaderLoadState.loading));
    await _fetchHeader();
  }

  Future<void> retryPosts() async {
    if (_target == null) return;
    _nextCursor = null;
    _emit(_state.copyWith(postsState: PostsLoadState.loading, posts: []));
    await _fetchFirstPostsPage();
  }

  Future<void> loadMore() async {
    if (_target == null) return;
    if (_state.isLoadingMore) return;
    if (_nextCursor == null) return;

    _emit(_state.copyWith(isLoadingMore: true));
    try {
      final page = await _loadPostsPage(
        _target!,
        pageSize: 20,
        cursor: _nextCursor,
      );
      _nextCursor = page.nextCursor;
      final appended = [..._state.posts, ...page.items];
      _emit(
        _state.copyWith(
          postsState: PostsLoadState.data,
          posts: appended,
          isLoadingMore: false,
          canLoadMore: page.nextCursor != null,
        ),
      );
    } catch (_) {
      _emit(_state.copyWith(isLoadingMore: false));
    }
  }
}
