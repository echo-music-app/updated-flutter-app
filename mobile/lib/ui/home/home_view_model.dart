import 'package:flutter/foundation.dart';
import 'package:mobile/ui/home/home_feed_repository.dart';

enum HomeScreenState { loading, empty, error, data }

enum PostPrivacy { public, friendsOnly, onlyMe }

enum HomeFeedCategory { ibsFirstYear, ibsCorporateFinance, budapest, friends }

class HomeFeedComment {
  const HomeFeedComment({
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String authorName;
  final String text;
  final DateTime createdAt;
}

class HomeFeedPostEngagement {
  const HomeFeedPostEngagement({
    required this.likeCount,
    required this.commentCount,
    required this.currentUserLiked,
  });

  final int likeCount;
  final int commentCount;
  final bool currentUserLiked;
}

class HomeFeedPost {
  const HomeFeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userHandle,
    this.userAvatarUrl,
    this.text,
    this.spotifyUrl,
    this.privacy = PostPrivacy.public,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.currentUserLiked = false,
    this.comments = const <HomeFeedComment>[],
    this.categories = const <HomeFeedCategory>{},
  });

  final String id;
  final String userId;
  final String userName;
  final String userHandle;
  final String? userAvatarUrl;
  final String? text;
  final String? spotifyUrl;
  final PostPrivacy privacy;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool currentUserLiked;
  final List<HomeFeedComment> comments;
  final Set<HomeFeedCategory> categories;

  HomeFeedPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userHandle,
    String? userAvatarUrl,
    String? text,
    String? spotifyUrl,
    PostPrivacy? privacy,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    bool? currentUserLiked,
    List<HomeFeedComment>? comments,
    Set<HomeFeedCategory>? categories,
  }) {
    return HomeFeedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userHandle: userHandle ?? this.userHandle,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      text: text ?? this.text,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      currentUserLiked: currentUserLiked ?? this.currentUserLiked,
      comments: comments ?? this.comments,
      categories: categories ?? this.categories,
    );
  }
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({HomeFeedRepository? repository}) : _repository = repository {
    if (_repository != null) {
      loadFeed();
    }
  }

  final HomeFeedRepository? _repository;

  HomeScreenState _state = HomeScreenState.data;
  HomeScreenState get state => _state;

  HomeFeedCategory _activeCategory = HomeFeedCategory.ibsFirstYear;
  HomeFeedCategory get activeCategory => _activeCategory;

  List<HomeFeedPost> _posts = const [];
  List<HomeFeedPost> get posts => _posts;
  List<HomeFeedPost> get filteredPosts => _posts
      .where((post) => post.categories.contains(_activeCategory))
      .toList(growable: false);

  void setCategory(HomeFeedCategory category) {
    if (_activeCategory == category) return;
    _activeCategory = category;
    notifyListeners();
  }

  void _emit({required HomeScreenState state, List<HomeFeedPost>? posts}) {
    _state = state;
    if (posts != null) {
      _posts = posts;
    }
    notifyListeners();
  }

  Future<void> loadFeed() async {
    final repository = _repository;
    if (repository == null) return;

    _emit(state: HomeScreenState.loading);
    try {
      final page = await repository.getFollowingFeed(pageSize: 20);
      final items = [...page.items];
      if (items.isEmpty) {
        _emit(state: HomeScreenState.empty, posts: const []);
        return;
      }
      _emit(state: HomeScreenState.data, posts: items);
    } on HomeFeedAuthException {
      _emit(state: HomeScreenState.error);
    } catch (_) {
      _emit(state: HomeScreenState.error);
    }
  }

  Future<void> toggleLike(String postId) async {
    final repository = _repository;
    final target = _findPost(postId);
    if (target == null) return;

    final liked = !target.currentUserLiked;
    final optimisticCount = liked
        ? target.likeCount + 1
        : (target.likeCount > 0 ? target.likeCount - 1 : 0);
    _updatePost(
      postId,
      (post) =>
          post.copyWith(currentUserLiked: liked, likeCount: optimisticCount),
    );

    if (repository == null) return;
    try {
      final engagement = liked
          ? await repository.likePost(postId)
          : await repository.unlikePost(postId);
      _updatePost(
        postId,
        (post) => post.copyWith(
          currentUserLiked: engagement.currentUserLiked,
          likeCount: engagement.likeCount,
          commentCount: engagement.commentCount,
        ),
      );
    } catch (_) {
      _updatePost(
        postId,
        (post) => post.copyWith(
          currentUserLiked: target.currentUserLiked,
          likeCount: target.likeCount,
          commentCount: target.commentCount,
        ),
      );
    }
  }

  Future<List<HomeFeedComment>> loadComments(String postId) async {
    final repository = _repository;
    if (repository == null) {
      return _findPost(postId)?.comments ?? const [];
    }
    try {
      final comments = await repository.listPostComments(postId);
      _updatePost(postId, (post) => post.copyWith(comments: comments));
      return comments;
    } catch (_) {
      return _findPost(postId)?.comments ?? const [];
    }
  }

  Future<HomeFeedComment?> addComment(String postId, String commentText) async {
    final trimmed = commentText.trim();
    if (trimmed.isEmpty) return null;
    final repository = _repository;
    if (repository == null) {
      final created = HomeFeedComment(
        authorName: 'You',
        text: trimmed,
        createdAt: DateTime.now(),
      );
      _updatePost(
        postId,
        (post) => post.copyWith(
          commentCount: post.commentCount + 1,
          comments: [...post.comments, created],
        ),
      );
      return created;
    }
    try {
      final created = await repository.createPostComment(postId, trimmed);
      _updatePost(
        postId,
        (post) => post.copyWith(
          commentCount: post.commentCount + 1,
          comments: [...post.comments, created],
        ),
      );
      return created;
    } catch (_) {
      return null;
    }
  }

  void _updatePost(
    String postId,
    HomeFeedPost Function(HomeFeedPost post) map,
  ) {
    final updated = _posts
        .map((post) {
          if (post.id != postId) return post;
          return map(post);
        })
        .toList(growable: false);
    _emit(state: _state, posts: updated);
  }

  HomeFeedPost? _findPost(String postId) {
    for (final post in _posts) {
      if (post.id == postId) return post;
    }
    return null;
  }
}
