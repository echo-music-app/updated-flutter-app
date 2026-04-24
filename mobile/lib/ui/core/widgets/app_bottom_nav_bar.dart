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
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    int unreadCount;
    try {
      unreadCount = context.watch<MessageBadgeController>().unreadCount;
    } on ProviderNotFoundException {
      unreadCount = 0;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final unselectedColor = colorScheme.onSurfaceVariant;

    Color iconColor(AppBottomNavTab tab) =>
        currentTab == tab ? Colors.white : unselectedColor;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIconButton(
                tooltip: 'Home',
                isSelected: currentTab == AppBottomNavTab.home,
                bubbleColor: _tabBubbleColor(AppBottomNavTab.home),
                onPressed: () => _navigateTo(context, AppBottomNavTab.home),
                child: Icon(
                  Icons.home_rounded,
                  color: iconColor(AppBottomNavTab.home),
                ),
              ),
              _NavIconButton(
                tooltip: 'Search',
                isSelected: currentTab == AppBottomNavTab.search,
                bubbleColor: _tabBubbleColor(AppBottomNavTab.search),
                onPressed: () => _navigateTo(context, AppBottomNavTab.search),
                child: Icon(
                  Icons.search_rounded,
                  color: iconColor(AppBottomNavTab.search),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B5BFF), Color(0xFF5A3FFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5A3FFF).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => context.go(Routes.createPost),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create'),
                ),
              ),
              _NavIconButton(
                tooltip: 'Messages',
                isSelected: currentTab == AppBottomNavTab.messages,
                bubbleColor: _tabBubbleColor(AppBottomNavTab.messages),
                onPressed: () => _navigateTo(context, AppBottomNavTab.messages),
                child: _MessageBubbleIcon(
                  bubbleColor: iconColor(AppBottomNavTab.messages),
                  dotColor: currentTab == AppBottomNavTab.messages
                      ? _tabBubbleColor(AppBottomNavTab.messages)
                      : colorScheme.surface,
                  unreadCount: unreadCount,
                ),
              ),
              _NavIconButton(
                tooltip: 'Profile',
                isSelected: currentTab == AppBottomNavTab.profile,
                bubbleColor: _tabBubbleColor(AppBottomNavTab.profile),
                onPressed: () => _navigateTo(context, AppBottomNavTab.profile),
                child: Icon(
                  Icons.person_rounded,
                  color: iconColor(AppBottomNavTab.profile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.tooltip,
    required this.isSelected,
    required this.bubbleColor,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final bool isSelected;
  final Color bubbleColor;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: isSelected ? const Offset(0, -0.09) : Offset.zero,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: isSelected ? 1.06 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? bubbleColor : Colors.transparent,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: bubbleColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: child,
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

Color _tabBubbleColor(AppBottomNavTab tab) {
  switch (tab) {
    case AppBottomNavTab.home:
      return const Color(0xFF4F7CFF);
    case AppBottomNavTab.search:
      return const Color(0xFF00A991);
    case AppBottomNavTab.messages:
      return const Color(0xFF8C5BFF);
    case AppBottomNavTab.profile:
      return const Color(0xFFFF6B4A);
  }
}
