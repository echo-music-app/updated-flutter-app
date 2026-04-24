import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/core/widgets/tab_accent_strip.dart';
import 'package:mobile/ui/core/widgets/trend_surfaces.dart';
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
            centerTitle: true,
          ),
          body: DecoratedBox(
            decoration: appTrendBackground(context),
            child: Column(
              children: [
                const TabAccentStrip(tab: AppBottomNavTab.messages),
                Expanded(
                  child: _isConversationMode
                      ? _buildConversationBody()
                      : _buildInboxBody(context),
                ),
              ],
            ),
          ),
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
        return const _CenterStateCard(
          icon: Icons.mark_chat_unread_rounded,
          title: 'No messages yet',
          subtitle: 'Open a friend profile and tap Message to start chatting.',
        );
      case MessagesInboxState.error:
        return _CenterStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load messages',
          subtitle: 'Please try again.',
          actionLabel: 'Retry',
          onAction: widget.viewModel.loadInbox,
        );
      case MessagesInboxState.authRequired:
        return _CenterStateCard(
          icon: Icons.lock_clock_outlined,
          title: 'Session expired',
          subtitle: 'Please login again.',
          actionLabel: 'Go to login',
          onAction: () => context.go(Routes.login),
        );
      case MessagesInboxState.data:
        final badge = context.watch<MessageBadgeController>();
        final filteredThreads = widget.viewModel.threads
            .where((thread) {
              final query = _threadQuery.trim().toLowerCase();
              if (query.isEmpty) return true;
              return thread.username.toLowerCase().contains(query) ||
                  thread.lastMessagePreview.toLowerCase().contains(query);
            })
            .toList(growable: false);
        return RefreshIndicator(
          onRefresh: widget.viewModel.loadInbox,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            children: [
              _InboxSummaryCard(count: filteredThreads.length),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Text(
                '${filteredThreads.length} conversation(s)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (filteredThreads.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text('No conversations match your search.'),
                  ),
                )
              else
                ...filteredThreads.map((thread) {
                  final unread = badge.unreadForThread(thread.userId);
                  return _InboxThreadCard(
                    username: thread.username,
                    preview: thread.lastMessagePreview,
                    trailing: unread > 0
                        ? _UnreadThreadBadge(count: unread)
                        : Text(
                            _shortDate(thread.lastMessageAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                    onTap: () => context.push(
                      '${Routes.messages}/${Uri.encodeComponent(thread.userId)}',
                    ),
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
        return const _CenterStateCard(
          icon: Icons.people_alt_outlined,
          title: 'Messaging is limited',
          subtitle: 'Messaging is only available between friends.',
        );
      case MessagesConversationState.authRequired:
        return const _CenterStateCard(
          icon: Icons.lock_clock_outlined,
          title: 'Session expired',
          subtitle: 'Please login again.',
        );
      case MessagesConversationState.error:
        return _CenterStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this conversation',
          subtitle: 'Please try again.',
          actionLabel: 'Retry',
          onAction: () => widget.viewModel.openConversation(widget.userId!),
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(12),
                  itemCount: widget.viewModel.messages.length,
                  itemBuilder: (context, index) {
                    final message = widget.viewModel.messages[index];
                    return Align(
                      alignment: message.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        constraints: const BoxConstraints(maxWidth: 290),
                        decoration: BoxDecoration(
                          color: message.isMine
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.22)
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.82),
                          border: Border.all(
                            color: message.isMine
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.shadow.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                  child: TrendPanel(
                    borderRadius: BorderRadius.circular(18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ],
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
    final isToday =
        now.year == value.year &&
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

class _InboxSummaryCard extends StatelessWidget {
  const _InboxSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.95),
            scheme.tertiary.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_chat_read_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count active conversation(s)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Realtime',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterStateCard extends StatelessWidget {
  const _CenterStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: TrendPanel(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxThreadCard extends StatelessWidget {
  const _InboxThreadCard({
    required this.username,
    required this.preview,
    required this.trailing,
    required this.onTap,
  });

  final String username;
  final String preview;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TrendPanel(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                ),
              ),
              title: Text(
                username,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
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
