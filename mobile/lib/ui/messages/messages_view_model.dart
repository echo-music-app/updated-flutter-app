import 'package:flutter/foundation.dart';
import 'package:mobile/ui/messages/messages_repository.dart';

enum MessagesInboxState { loading, data, empty, error, authRequired }

enum MessagesConversationState {
  idle,
  loading,
  data,
  empty,
  error,
  authRequired,
  forbidden,
}

class MessagesViewModel extends ChangeNotifier {
  MessagesViewModel({
    required MessagesRepository repository,
    void Function()? onAuthExpired,
  }) : _repository = repository,
       _onAuthExpired = onAuthExpired {
    if (_cachedInboxState != null) {
      _inboxState = _cachedInboxState!;
      _threads = _cachedThreads;
    }
  }

  final MessagesRepository _repository;
  final void Function()? _onAuthExpired;

  static MessagesInboxState? _cachedInboxState;
  static List<MessageThreadSummary> _cachedThreads = const [];
  static final Map<String, _CachedConversation> _cachedConversations = {};

  MessagesInboxState _inboxState = MessagesInboxState.loading;
  MessagesInboxState get inboxState => _inboxState;

  MessagesConversationState _conversationState = MessagesConversationState.idle;
  MessagesConversationState get conversationState => _conversationState;

  List<MessageThreadSummary> _threads = const [];
  List<MessageThreadSummary> get threads => _threads;

  List<DirectMessage> _messages = const [];
  List<DirectMessage> get messages => _messages;

  String? _targetUserId;
  String? get targetUserId => _targetUserId;

  String? _targetUsername;
  String? get targetUsername => _targetUsername;

  bool _isSending = false;
  bool get isSending => _isSending;

  void _emitInbox({
    required MessagesInboxState state,
    List<MessageThreadSummary>? threads,
  }) {
    _inboxState = state;
    if (threads != null) _threads = threads;
    notifyListeners();
  }

  void _emitConversation({
    required MessagesConversationState state,
    List<DirectMessage>? messages,
    String? targetUserId,
    String? targetUsername,
    bool? isSending,
  }) {
    _conversationState = state;
    if (messages != null) _messages = messages;
    if (targetUserId != null) _targetUserId = targetUserId;
    if (targetUsername != null) _targetUsername = targetUsername;
    if (isSending != null) _isSending = isSending;
    notifyListeners();
  }

  Future<void> loadInbox() async {
    if (_cachedInboxState != null) {
      _emitInbox(state: _cachedInboxState!, threads: _cachedThreads);
    } else {
      _emitInbox(state: MessagesInboxState.loading);
    }
    try {
      final items = await _repository.listThreads();
      if (items.isEmpty) {
        _cachedInboxState = MessagesInboxState.empty;
        _cachedThreads = const [];
        _emitInbox(state: MessagesInboxState.empty, threads: const []);
        return;
      }
      _cachedInboxState = MessagesInboxState.data;
      _cachedThreads = items;
      _emitInbox(state: MessagesInboxState.data, threads: items);
    } on MessagesAuthException {
      _onAuthExpired?.call();
      _cachedInboxState = null;
      _cachedThreads = const [];
      _cachedConversations.clear();
      _emitInbox(state: MessagesInboxState.authRequired, threads: const []);
    } catch (_) {
      if (_cachedInboxState == null) {
        _cachedThreads = const [];
      }
      _emitInbox(state: MessagesInboxState.error, threads: const []);
    }
  }

  Future<void> openConversation(String userId) async {
    final cachedConversation = _cachedConversations[userId];
    if (cachedConversation != null) {
      _emitConversation(
        state: cachedConversation.state,
        messages: cachedConversation.messages,
        targetUserId: cachedConversation.userId,
        targetUsername: cachedConversation.username,
        isSending: false,
      );
    } else {
      _targetUsername = null;
      _emitConversation(
        state: MessagesConversationState.loading,
        messages: const [],
        targetUserId: userId,
        targetUsername: null,
        isSending: false,
      );
    }
    try {
      final thread = await _repository.getConversation(userId);
      final nextState = thread.items.isEmpty
          ? MessagesConversationState.empty
          : MessagesConversationState.data;
      _cachedConversations[userId] = _CachedConversation(
        userId: thread.targetUserId,
        username: thread.targetUsername,
        messages: thread.items,
        state: nextState,
      );
      _emitConversation(
        state: nextState,
        messages: thread.items,
        targetUserId: thread.targetUserId,
        targetUsername: thread.targetUsername,
        isSending: false,
      );
    } on MessagesPermissionException {
      _emitConversation(
        state: MessagesConversationState.forbidden,
        messages: const [],
        targetUserId: userId,
        isSending: false,
      );
      _cachedConversations.remove(userId);
    } on MessagesAuthException {
      _onAuthExpired?.call();
      _cachedInboxState = null;
      _cachedThreads = const [];
      _cachedConversations.clear();
      _emitConversation(
        state: MessagesConversationState.authRequired,
        messages: const [],
        targetUserId: userId,
        isSending: false,
      );
    } catch (_) {
      _emitConversation(
        state: MessagesConversationState.error,
        messages: const [],
        targetUserId: userId,
        isSending: false,
      );
    }
  }

  Future<bool> send(String text) async {
    final userId = _targetUserId;
    if (userId == null || userId.isEmpty) return false;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    _emitConversation(state: _conversationState, isSending: true);

    try {
      final sent = await _repository.sendMessage(userId, trimmed);
      final nextMessages = [..._messages, sent];
      _cachedConversations[userId] = _CachedConversation(
        userId: userId,
        username: _targetUsername,
        messages: nextMessages,
        state: MessagesConversationState.data,
      );
      _emitConversation(
        state: MessagesConversationState.data,
        messages: nextMessages,
        isSending: false,
      );
      await loadInbox();
      return true;
    } on MessagesPermissionException {
      _emitConversation(
        state: MessagesConversationState.forbidden,
        isSending: false,
      );
      return false;
    } on MessagesAuthException {
      _onAuthExpired?.call();
      _cachedInboxState = null;
      _cachedThreads = const [];
      _cachedConversations.clear();
      _emitConversation(
        state: MessagesConversationState.authRequired,
        isSending: false,
      );
      return false;
    } catch (_) {
      _emitConversation(state: _conversationState, isSending: false);
      return false;
    }
  }
}

class _CachedConversation {
  const _CachedConversation({
    required this.userId,
    required this.username,
    required this.messages,
    required this.state,
  });

  final String userId;
  final String? username;
  final List<DirectMessage> messages;
  final MessagesConversationState state;
}
