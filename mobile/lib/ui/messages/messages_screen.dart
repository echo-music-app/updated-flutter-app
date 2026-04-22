import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/messages/message_badge_controller.dart';
import 'package:mobile/ui/messages/messages_view_model.dart';
import 'package:provider/provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.viewModel, this.userId});

  final MessagesViewModel viewModel;
  final String? userId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _threadSearchController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  String _threadQuery = '';

  bool get _isConversationMode =>
      widget.userId != null && widget.userId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final badge = context.read<MessageBadgeController>();
    unawaited(badge.refresh());

    if (_isConversationMode) {
      badge.markThreadSeen(widget.userId!);
      widget.viewModel.openConversation(widget.userId!);
    } else {
      widget.viewModel.loadInbox();
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _threadSearchController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            leading: const AppTopNavLeading(),
            title: Text(_resolveTitle()),
            centerTitle: false,
          ),
          body: _isConversationMode
              ? _buildConversationBody()
              : _buildInboxBody(context),
          bottomNavigationBar: const AppBottomNavBar(
            currentTab: AppBottomNavTab.messages,
          ),
        );
      },
    );
  }

  String _resolveTitle() {
    if (!_isConversationMode) return 'Messages';
    return widget.viewModel.targetUsername ?? 'Chat';
  }

  Widget _buildInboxBody(BuildContext context) {
    switch (widget.viewModel.inboxState) {
      case MessagesInboxState.loading:
        return const Center(child: CircularProgressIndicator());
      case MessagesInboxState.empty:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No messages yet. Open a friend profile and tap Message.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case MessagesInboxState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load messages.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.viewModel.loadInbox,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case MessagesInboxState.authRequired:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session expired. Please login again.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('Go to login'),
              ),
            ],
          ),
        );
      case MessagesInboxState.data:
        final badge = context.watch<MessageBadgeController>();
        final filteredThreads = widget.viewModel.threads.where((thread) {
          final query = _threadQuery.trim().toLowerCase();
          if (query.isEmpty) return true;
          return thread.username.toLowerCase().contains(query) ||
              thread.lastMessagePreview.toLowerCase().contains(query);
        }).toList(growable: false);
        return RefreshIndicator(
          onRefresh: widget.viewModel.loadInbox,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            children: [
              TextField(
                controller: _threadSearchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search messages',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _threadQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear',
                          onPressed: () {
                            _threadSearchController.clear();
                            setState(() => _threadQuery = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _threadQuery = value),
              ),
              const SizedBox(height: 10),
              Text(
                '${filteredThreads.length} conversation(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (filteredThreads.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('No conversations match your search.')),
                )
              else
                ...filteredThreads.map((thread) {
                  final unread = badge.unreadForThread(thread.userId);
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                        leading: CircleAvatar(
                          child: Text(
                            thread.username.isNotEmpty
                                ? thread.username[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(thread.username),
                        subtitle: Text(
                          thread.lastMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: unread > 0
                            ? _UnreadThreadBadge(count: unread)
                            : Text(
                                _shortDate(thread.lastMessageAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                        onTap: () => context.push(
                          '${Routes.messages}/${Uri.encodeComponent(thread.userId)}',
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
            ],
          ),
        );
    }
  }

  Widget _buildConversationBody() {
    switch (widget.viewModel.conversationState) {
      case MessagesConversationState.idle:
      case MessagesConversationState.loading:
        return const Center(child: CircularProgressIndicator());
      case MessagesConversationState.forbidden:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Messaging is only available between friends.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case MessagesConversationState.authRequired:
        return const Center(
          child: Text('Session expired. Please login again.'),
        );
      case MessagesConversationState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load this conversation.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    widget.viewModel.openConversation(widget.userId!),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case MessagesConversationState.empty:
      case MessagesConversationState.data:
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
            Expanded(
              child: ListView.builder(
                reverse: false,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(12),
                itemCount: widget.viewModel.messages.length,
                itemBuilder: (context, index) {
                  final message = widget.viewModel.messages[index];
                  return Align(
                    alignment: message.isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                      ),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: message.isMine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: message.isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(message.text),
                          const SizedBox(height: 4),
                          Text(
                            _shortTime(message.createdAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.viewModel.conversationState ==
                MessagesConversationState.empty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('No messages yet. Say hello.'),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _composerFocusNode,
                            controller: _composerController,
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Write a message...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: widget.viewModel.isSending ? null : _send,
                          icon: widget.viewModel.isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          ),
        );
    }
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final text = _composerController.text;
    if (text.trim().isEmpty) return;

    final success = await widget.viewModel.send(text);
    if (!mounted) return;

    if (success) {
      _composerController.clear();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not send message.')));
  }

  String _shortDate(DateTime value) {
    final now = DateTime.now();
    final isToday = now.year == value.year &&
        now.month == value.month &&
        now.day == value.day;
    if (isToday) return _shortTime(value);
    return '${value.month}/${value.day}';
  }

  String _shortTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _UnreadThreadBadge extends StatelessWidget {
  const _UnreadThreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
