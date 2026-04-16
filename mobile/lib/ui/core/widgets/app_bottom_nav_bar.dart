import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/messages/message_badge_controller.dart';
import 'package:provider/provider.dart';

enum AppBottomNavTab { home, search, messages, profile }

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, this.currentTab});

  final AppBottomNavTab? currentTab;

  void _navigateTo(BuildContext context, AppBottomNavTab tab) {
    if (tab == AppBottomNavTab.profile) {
      final currentPath = GoRouterState.of(context).uri.path;
      final isProfileSubList =
          currentPath == Routes.friendsFollowers ||
          currentPath == Routes.friendsFollowing;
      if (isProfileSubList && Navigator.canPop(context)) {
        context.pop();
        return;
      }
      context.go(Routes.profile);
      return;
    }
    if (tab == currentTab) return;
    switch (tab) {
      case AppBottomNavTab.home:
        context.go(Routes.home);
      case AppBottomNavTab.search:
        context.go(Routes.search);
      case AppBottomNavTab.messages:
        context.go(Routes.messages);
      case AppBottomNavTab.profile:
        // handled above
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    int unreadCount;
    try {
      unreadCount = context.watch<MessageBadgeController>().unreadCount;
    } on ProviderNotFoundException {
      // Some widget tests mount this bar without global providers.
      unreadCount = 0;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    Color iconColor(AppBottomNavTab tab) =>
        currentTab == tab ? selectedColor : unselectedColor;

    return BottomAppBar(
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: 'Home',
                icon: Icon(
                  Icons.home_rounded,
                  color: iconColor(AppBottomNavTab.home),
                ),
                onPressed: () => _navigateTo(context, AppBottomNavTab.home),
              ),
              IconButton(
                tooltip: 'Search',
                icon: Icon(
                  Icons.search_rounded,
                  color: iconColor(AppBottomNavTab.search),
                ),
                onPressed: () => _navigateTo(context, AppBottomNavTab.search),
              ),
              FilledButton.icon(
                onPressed: () => context.go(Routes.createPost),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create'),
              ),
              IconButton(
                tooltip: 'Messages',
                icon: _MessageBubbleIcon(
                  bubbleColor: iconColor(AppBottomNavTab.messages),
                  dotColor: colorScheme.surface,
                  unreadCount: unreadCount,
                ),
                onPressed: () => _navigateTo(context, AppBottomNavTab.messages),
              ),
              IconButton(
                tooltip: 'Profile',
                icon: Icon(
                  Icons.person_rounded,
                  color: iconColor(AppBottomNavTab.profile),
                ),
                onPressed: () => _navigateTo(context, AppBottomNavTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubbleIcon extends StatelessWidget {
  const _MessageBubbleIcon({
    required this.bubbleColor,
    required this.dotColor,
    required this.unreadCount,
  });

  final Color bubbleColor;
  final Color dotColor;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble_rounded, color: bubbleColor, size: 26),
          Positioned(
            top: 11,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(dotColor),
                const SizedBox(width: 4),
                _Dot(dotColor),
                const SizedBox(width: 4),
                _Dot(dotColor),
              ],
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -4,
              child: _UnreadBadge(count: unreadCount),
            ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: const BoxDecoration(
        color: Color(0xFFE94B6A),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
