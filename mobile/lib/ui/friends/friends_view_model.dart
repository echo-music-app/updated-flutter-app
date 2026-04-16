import 'package:flutter/foundation.dart';
import 'package:mobile/ui/friends/friends_repository.dart';

enum FriendsState { loading, data, empty, error, authRequired }

class FriendsViewModel extends ChangeNotifier {
  FriendsViewModel({
    required FriendsRepository repository,
    required FriendListType listType,
    void Function()? onAuthExpired,
  }) : _repository = repository,
       _listType = listType,
       _onAuthExpired = onAuthExpired {
    final cachedState = _cacheStateByType[_listType];
    final cachedFriends = _cacheByType[_listType];
    if (cachedState != null) {
      _state = cachedState;
      _friends = cachedFriends ?? const [];
    }
  }

  final FriendsRepository _repository;
  final FriendListType _listType;
  final void Function()? _onAuthExpired;
  static final Map<FriendListType, List<FriendListItem>> _cacheByType = {};
  static final Map<FriendListType, FriendsState> _cacheStateByType = {};

  FriendsState _state = FriendsState.loading;
  FriendsState get state => _state;

  List<FriendListItem> _friends = const [];
  List<FriendListItem> get friends => _friends;

  void _emit({required FriendsState state, List<FriendListItem>? friends}) {
    _state = state;
    if (friends != null) _friends = friends;
    notifyListeners();
  }

  Future<void> load() async {
    final cachedState = _cacheStateByType[_listType];
    final cached = _cacheByType[_listType];
    if (cachedState != null) {
      _emit(state: cachedState, friends: cached ?? const []);
    } else if (cached != null && cached.isNotEmpty) {
      _emit(state: FriendsState.data, friends: cached);
    } else {
      _emit(state: FriendsState.loading);
    }
    try {
      final items = await _repository.listFriends(_listType);
      if (items.isEmpty) {
        _cacheByType[_listType] = const [];
        _cacheStateByType[_listType] = FriendsState.empty;
        _emit(state: FriendsState.empty, friends: const []);
        return;
      }
      _cacheByType[_listType] = items;
      _cacheStateByType[_listType] = FriendsState.data;
      _emit(state: FriendsState.data, friends: items);
    } on FriendsAuthException {
      _onAuthExpired?.call();
      _cacheByType.remove(_listType);
      _cacheStateByType.remove(_listType);
      _emit(state: FriendsState.authRequired, friends: const []);
    } catch (_) {
      _emit(state: FriendsState.error, friends: const []);
    }
  }
}
