import 'package:flutter/foundation.dart';
import 'package:mobile/ui/home/home_feed_repository.dart';

enum HomeScreenState { loading, empty, error, data }

enum PostPrivacy { public, friendsOnly, onlyMe }

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

  List<HomeFeedPost> _posts = const [];
  List<HomeFeedPost> get posts => _posts;

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
}
