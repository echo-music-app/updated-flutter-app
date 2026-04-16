import 'package:flutter/foundation.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_header.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/use_cases/resolve_profile_target.dart';
import 'package:mobile/features/profile_view/domain/use_cases/update_own_profile.dart';
import 'package:mobile/features/profile_view/domain/use_cases/upload_own_avatar.dart';

enum HeaderLoadState { loading, data, empty, error, notFound, authRequired }

enum PostsLoadState { loading, data, empty, error, authRequired }

class ProfileViewState {
  const ProfileViewState({
    this.headerState = HeaderLoadState.loading,
    this.header,
    this.postsState = PostsLoadState.loading,
    this.posts = const [],
    this.totalPostsCount = 0,
    this.isLoadingMore = false,
    this.canLoadMore = false,
    this.isSavingBio = false,
    this.isUploadingAvatar = false,
    this.followRelationStatus = FollowRelationStatus.none,
    this.isFollowActionInProgress = false,
    this.followStatusLoaded = false,
    this.localAvatarPath,
  });

  final HeaderLoadState headerState;
  final ProfileHeader? header;
  final PostsLoadState postsState;
  final List<ProfilePostSummary> posts;
  final int totalPostsCount;
  final bool isLoadingMore;
  final bool canLoadMore;
  final bool isSavingBio;
  final bool isUploadingAvatar;
  final FollowRelationStatus followRelationStatus;
  final bool isFollowActionInProgress;
  final bool followStatusLoaded;
  final String? localAvatarPath;

  ProfileViewState copyWith({
    HeaderLoadState? headerState,
    ProfileHeader? header,
    bool clearHeader = false,
    PostsLoadState? postsState,
    List<ProfilePostSummary>? posts,
    int? totalPostsCount,
    bool? isLoadingMore,
    bool? canLoadMore,
    bool? isSavingBio,
    bool? isUploadingAvatar,
    FollowRelationStatus? followRelationStatus,
    bool? isFollowActionInProgress,
    bool? followStatusLoaded,
    String? localAvatarPath,
    bool clearLocalAvatarPath = false,
  }) {
    return ProfileViewState(
      headerState: headerState ?? this.headerState,
      header: clearHeader ? null : (header ?? this.header),
      postsState: postsState ?? this.postsState,
      posts: posts ?? this.posts,
      totalPostsCount: totalPostsCount ?? this.totalPostsCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      isSavingBio: isSavingBio ?? this.isSavingBio,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      followRelationStatus: followRelationStatus ?? this.followRelationStatus,
      isFollowActionInProgress:
          isFollowActionInProgress ?? this.isFollowActionInProgress,
      followStatusLoaded: followStatusLoaded ?? this.followStatusLoaded,
      localAvatarPath: clearLocalAvatarPath
          ? null
          : (localAvatarPath ?? this.localAvatarPath),
    );
  }
}

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required ResolveProfileTargetUseCase resolveTarget,
    required LoadProfileHeaderUseCase loadHeader,
    required LoadProfilePostsPageUseCase loadPostsPage,
    required UpdateOwnProfileUseCase updateOwnProfile,
    required UploadOwnAvatarUseCase uploadOwnAvatar,
    required String? currentUserId,
    Future<FollowRelationStatus> Function(String userId)? getFollowStatus,
    Future<void> Function(String userId)? sendFollowRequest,
    Future<void> Function(String userId)? acceptFollowRequest,
  }) : _resolveTarget = resolveTarget,
       _loadHeader = loadHeader,
       _loadPostsPage = loadPostsPage,
       _updateOwnProfile = updateOwnProfile,
       _uploadOwnAvatar = uploadOwnAvatar,
       _currentUserId = currentUserId,
       _getFollowStatus = getFollowStatus,
       _sendFollowRequest = sendFollowRequest,
       _acceptFollowRequest = acceptFollowRequest;

  final ResolveProfileTargetUseCase _resolveTarget;
  final LoadProfileHeaderUseCase _loadHeader;
  final LoadProfilePostsPageUseCase _loadPostsPage;
  final UpdateOwnProfileUseCase _updateOwnProfile;
  final UploadOwnAvatarUseCase _uploadOwnAvatar;
  final String? _currentUserId;
  final Future<FollowRelationStatus> Function(String userId)? _getFollowStatus;
  final Future<void> Function(String userId)? _sendFollowRequest;
  final Future<void> Function(String userId)? _acceptFollowRequest;

  ProfileViewState _state = const ProfileViewState();
  ProfileViewState get state => _state;

  ProfileRouteTarget? _target;
  String? _nextCursor;

  void _emit(ProfileViewState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> loadProfile({String? userId}) async {
    _target = _resolveTarget.resolve(
      userId: userId,
      currentUserId: _currentUserId,
    );
    _nextCursor = null;
    _emit(const ProfileViewState());

    await Future.wait([
      _fetchHeader(),
      _fetchFirstPostsPage(),
      _fetchFollowStatus(),
    ]);
  }

  Future<void> _fetchFollowStatus() async {
    final target = _target;
    final targetUserId = target?.targetUserId;
    if (target == null ||
        target.mode != ProfileMode.other ||
        targetUserId == null ||
        targetUserId.isEmpty ||
        _getFollowStatus == null) {
      return;
    }

    try {
      final status = await _getFollowStatus(targetUserId);
      _emit(
        _state.copyWith(followRelationStatus: status, followStatusLoaded: true),
      );
    } catch (_) {
      _emit(_state.copyWith(followStatusLoaded: true));
    }
  }

  Future<void> _fetchHeader() async {
    try {
      final header = await _loadHeader(_target!);
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.data,
          header: header,
          clearLocalAvatarPath: true,
        ),
      );
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.authRequired,
          clearHeader: true,
          clearLocalAvatarPath: true,
          postsState: PostsLoadState.authRequired,
          posts: [],
        ),
      );
    } on ProfileNotFoundException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.notFound,
          clearLocalAvatarPath: true,
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
          totalPostsCount: page.count,
          canLoadMore: page.nextCursor != null,
        ),
      );
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          postsState: PostsLoadState.authRequired,
          posts: [],
          totalPostsCount: 0,
          canLoadMore: false,
        ),
      );
    } catch (_) {
      _emit(
        _state.copyWith(
          postsState: PostsLoadState.error,
          posts: [],
          totalPostsCount: 0,
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

  Future<void> saveBio(String bio) async {
    if (_target?.mode != ProfileMode.own || _state.header == null) {
      throw const ProfileLoadException(
        'Bio can only be edited on your profile',
      );
    }

    _emit(_state.copyWith(isSavingBio: true));
    try {
      final updated = await _updateOwnProfile(bio: bio.trim());
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.data,
          header: updated,
          isSavingBio: false,
        ),
      );
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.authRequired,
          isSavingBio: false,
        ),
      );
      rethrow;
    } catch (_) {
      _emit(_state.copyWith(isSavingBio: false));
      rethrow;
    }
  }

  Future<void> uploadAvatar(String path) async {
    if (_target?.mode != ProfileMode.own || _state.header == null) {
      throw const ProfileLoadException(
        'Avatar can only be edited on your profile',
      );
    }

    _emit(_state.copyWith(isUploadingAvatar: true, localAvatarPath: path));

    try {
      final updated = await _uploadOwnAvatar(path);
      final withFreshAvatar = _appendAvatarVersion(updated);
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.data,
          header: withFreshAvatar,
          isUploadingAvatar: false,
          clearLocalAvatarPath: true,
        ),
      );
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.authRequired,
          isUploadingAvatar: false,
          clearLocalAvatarPath: true,
        ),
      );
      rethrow;
    } catch (_) {
      _emit(
        _state.copyWith(isUploadingAvatar: false, clearLocalAvatarPath: true),
      );
      rethrow;
    }
  }

  Future<void> performFollowAction() async {
    final target = _target;
    final targetUserId = target?.targetUserId;
    if (target == null ||
        target.mode != ProfileMode.other ||
        targetUserId == null ||
        targetUserId.isEmpty) {
      throw const ProfileLoadException(
        'Cannot update relationship for this profile',
      );
    }

    _emit(_state.copyWith(isFollowActionInProgress: true));
    try {
      if (_state.followRelationStatus == FollowRelationStatus.pendingIncoming) {
        if (_acceptFollowRequest == null) {
          throw const ProfileLoadException('Accept action is unavailable');
        }
        await _acceptFollowRequest(targetUserId);
      } else {
        if (_sendFollowRequest == null) {
          throw const ProfileLoadException('Follow action is unavailable');
        }
        await _sendFollowRequest(targetUserId);
      }

      final refreshed = _getFollowStatus == null
          ? FollowRelationStatus.accepted
          : await _getFollowStatus(targetUserId);

      ProfileHeader? refreshedHeader = _state.header;
      try {
        refreshedHeader = await _loadHeader(_target!);
      } catch (_) {
        // Keep existing header if refresh fails.
      }

      _emit(
        _state.copyWith(
          header: refreshedHeader,
          followRelationStatus: refreshed,
          followStatusLoaded: true,
          isFollowActionInProgress: false,
        ),
      );
    } on ProfileAuthException {
      _emit(
        _state.copyWith(
          headerState: HeaderLoadState.authRequired,
          isFollowActionInProgress: false,
        ),
      );
      rethrow;
    } catch (_) {
      _emit(_state.copyWith(isFollowActionInProgress: false));
      rethrow;
    }
  }

  ProfileHeader _appendAvatarVersion(ProfileHeader header) {
    final avatarUrl = header.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return header;
    }
    final separator = avatarUrl.contains('?') ? '&' : '?';
    return ProfileHeader(
      id: header.id,
      username: header.username,
      avatarUrl:
          '$avatarUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}',
      bio: header.bio,
      preferredGenres: header.preferredGenres,
      isArtist: header.isArtist,
      followersCount: header.followersCount,
      followingCount: header.followingCount,
      imageState: header.imageState,
      createdAt: header.createdAt,
    );
  }
}
