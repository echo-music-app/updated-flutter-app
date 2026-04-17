import 'package:flutter/foundation.dart';
import 'package:mobile/ui/notifications/notifications_repository.dart';

enum NotificationsState { loading, data, empty, error, authRequired }

class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    required NotificationsRepository repository,
    void Function()? onAuthExpired,
  }) : _repository = repository,
       _onAuthExpired = onAuthExpired;

  final NotificationsRepository _repository;
  final void Function()? _onAuthExpired;

  NotificationsState _state = NotificationsState.loading;
  NotificationsState get state => _state;

  List<FollowRequestNotification> _requests = const [];
  List<FollowRequestNotification> get requests => _requests;

  List<PostActivityNotification> _activities = const [];
  List<PostActivityNotification> get activities => _activities;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  void _emit({
    required NotificationsState state,
    List<FollowRequestNotification>? requests,
    List<PostActivityNotification>? activities,
    bool? isProcessing,
  }) {
    _state = state;
    if (requests != null) _requests = requests;
    if (activities != null) _activities = activities;
    if (isProcessing != null) _isProcessing = isProcessing;
    notifyListeners();
  }

  Future<void> load() async {
    _emit(state: NotificationsState.loading);
    try {
      final results = await Future.wait([
        _repository.listIncomingFollowRequests(),
        _repository.listPostActivityNotifications(),
      ]);
      final requests = results[0] as List<FollowRequestNotification>;
      final activities = results[1] as List<PostActivityNotification>;
      if (requests.isEmpty && activities.isEmpty) {
        _emit(
          state: NotificationsState.empty,
          requests: const [],
          activities: const [],
        );
        return;
      }
      _emit(
        state: NotificationsState.data,
        requests: requests,
        activities: activities,
      );
    } on NotificationsAuthException {
      _onAuthExpired?.call();
      _emit(
        state: NotificationsState.authRequired,
        requests: const [],
        activities: const [],
      );
    } catch (_) {
      _emit(
        state: NotificationsState.error,
        requests: const [],
        activities: const [],
      );
    }
  }

  Future<bool> acceptRequest(String requesterUserId) async {
    _emit(state: _state, isProcessing: true);
    try {
      await _repository.acceptFollowRequest(requesterUserId);
      await load();
      return true;
    } on NotificationsAuthException {
      _onAuthExpired?.call();
      _emit(
        state: NotificationsState.authRequired,
        requests: const [],
        activities: const [],
        isProcessing: false,
      );
      return false;
    } catch (_) {
      _emit(state: _state, isProcessing: false);
      return false;
    }
  }
}
