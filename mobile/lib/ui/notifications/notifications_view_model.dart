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

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  void _emit({
    required NotificationsState state,
    List<FollowRequestNotification>? requests,
    bool? isProcessing,
  }) {
    _state = state;
    if (requests != null) _requests = requests;
    if (isProcessing != null) _isProcessing = isProcessing;
    notifyListeners();
  }

  Future<void> load() async {
    _emit(state: NotificationsState.loading);
    try {
      final items = await _repository.listIncomingFollowRequests();
      if (items.isEmpty) {
        _emit(state: NotificationsState.empty, requests: const []);
        return;
      }
      _emit(state: NotificationsState.data, requests: items);
    } on NotificationsAuthException {
      _onAuthExpired?.call();
      _emit(state: NotificationsState.authRequired, requests: const []);
    } catch (_) {
      _emit(state: NotificationsState.error, requests: const []);
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
        isProcessing: false,
      );
      return false;
    } catch (_) {
      _emit(state: _state, isProcessing: false);
      return false;
    }
  }
}
