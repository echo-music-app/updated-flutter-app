import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/ui/messages/messages_repository.dart';

class MessageBadgeController extends ChangeNotifier {
  MessageBadgeController();

  MessagesRepository? _repository;
  Timer? _pollTimer;

  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _markAllSeenPending = false;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  Map<String, DateTime> _latestByUserId = const {};
  final Map<String, DateTime> _seenByUserId = {};
  final Map<String, int> _unreadByUserId = {};

  int unreadForThread(String userId) => _unreadByUserId[userId] ?? 0;

  void configure({
    required bool isAuthenticated,
    required MessagesRepository repository,
  }) {
    _repository = repository;

    if (!isAuthenticated) {
      _isAuthenticated = false;
      _isInitialized = false;
      _markAllSeenPending = false;
      _latestByUserId = const {};
      _seenByUserId.clear();
      _unreadByUserId.clear();
      _setUnreadCount(0);
      _stopPolling();
      return;
    }

    final wasAuthenticated = _isAuthenticated;
    _isAuthenticated = true;
    if (!wasAuthenticated) {
      _isInitialized = false;
      _markAllSeenPending = false;
      _latestByUserId = const {};
      _seenByUserId.clear();
      _unreadByUserId.clear();
      _setUnreadCount(0);
      _startPolling();
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (!_isAuthenticated || repository == null) return;

    try {
      final threads = await repository.listThreads();
      final latest = <String, DateTime>{
        for (final thread in threads)
          thread.userId: thread.lastMessageAt.toUtc(),
      };
      _latestByUserId = latest;

      if (!_isInitialized) {
        for (final entry in latest.entries) {
          _seenByUserId[entry.key] = entry.value;
        }
        _unreadByUserId.clear();
        _isInitialized = true;
        _setUnreadCount(0);
        return;
      }

      if (_markAllSeenPending) {
        _markAllSeenPending = false;
        for (final entry in latest.entries) {
          _seenByUserId[entry.key] = entry.value;
        }
        _unreadByUserId.clear();
        _setUnreadCount(0);
        return;
      }

      _recomputeUnread();
    } on MessagesAuthException {
      _isAuthenticated = false;
      _isInitialized = false;
      _markAllSeenPending = false;
      _latestByUserId = const {};
      _seenByUserId.clear();
      _unreadByUserId.clear();
      _setUnreadCount(0);
      _stopPolling();
    } catch (_) {
      // Keep the last known badge state for transient failures.
    }
  }

  void markAllSeen() {
    if (!_isInitialized || _latestByUserId.isEmpty) {
      _markAllSeenPending = true;
      return;
    }
    for (final entry in _latestByUserId.entries) {
      _seenByUserId[entry.key] = entry.value;
    }
    _unreadByUserId.clear();
    _setUnreadCount(0);
  }

  void markThreadSeen(String userId) {
    final latest = _latestByUserId[userId];
    if (latest == null) return;
    _seenByUserId[userId] = latest;
    _recomputeUnread();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(refresh()),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _recomputeUnread() {
    var unread = 0;
    final nextUnreadByUser = <String, int>{};
    for (final entry in _latestByUserId.entries) {
      final seenAt = _seenByUserId[entry.key];
      if (seenAt == null || entry.value.isAfter(seenAt)) {
        unread += 1;
        nextUnreadByUser[entry.key] = 1;
      }
    }
    _unreadByUserId
      ..clear()
      ..addAll(nextUnreadByUser);
    _setUnreadCount(unread);
  }

  void _setUnreadCount(int value) {
    if (_unreadCount == value) return;
    _unreadCount = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
