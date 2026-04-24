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
    final unselectedColor = colorScheme.onSurfaceVariant.withValues(
      alpha: 0.95,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavIconButton(
                    tooltip: 'Home',
                    isSelected: currentTab == AppBottomNavTab.home,
                    accentColor: _tabBubbleColor(AppBottomNavTab.home),
                    unselectedColor: unselectedColor,
                    onPressed: () => _navigateTo(context, AppBottomNavTab.home),
                    child: const Icon(Icons.home_rounded),
                  ),
                  _NavIconButton(
                    tooltip: 'Search',
                    isSelected: currentTab == AppBottomNavTab.search,
                    accentColor: _tabBubbleColor(AppBottomNavTab.search),
                    unselectedColor: unselectedColor,
                    onPressed: () =>
                        _navigateTo(context, AppBottomNavTab.search),
                    child: const Icon(Icons.search_rounded),
                  ),
                  const SizedBox(width: 56),
                  _NavIconButton(
                    tooltip: 'Messages',
                    isSelected: currentTab == AppBottomNavTab.messages,
                    accentColor: _tabBubbleColor(AppBottomNavTab.messages),
                    unselectedColor: unselectedColor,
                    onPressed: () =>
                        _navigateTo(context, AppBottomNavTab.messages),
                    child: _MessageBubbleIcon(
                      bubbleColor: currentTab == AppBottomNavTab.messages
                          ? _tabBubbleColor(AppBottomNavTab.messages)
                          : unselectedColor,
                      dotColor: currentTab == AppBottomNavTab.messages
                          ? colorScheme.surface
                          : colorScheme.surfaceContainerHighest,
                      unreadCount: unreadCount,
                    ),
                  ),
                  _NavIconButton(
                    tooltip: 'Profile',
                    isSelected: currentTab == AppBottomNavTab.profile,
                    accentColor: _tabBubbleColor(AppBottomNavTab.profile),
                    unselectedColor: unselectedColor,
                    onPressed: () =>
                        _navigateTo(context, AppBottomNavTab.profile),
                    child: const Icon(Icons.person_rounded),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -6,
                child: Center(
                  child: _CreateOrbButton(
                    onPressed: () => context.go(Routes.createPost),
                  ),
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
    required this.accentColor,
    required this.unselectedColor,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final bool isSelected;
  final Color accentColor;
  final Color unselectedColor;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? accentColor.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.20),
        border: Border.all(
          color: isSelected
              ? accentColor.withValues(alpha: 0.34)
              : Colors.black.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.08),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: IconTheme(
          data: IconThemeData(
            color: isSelected ? accentColor : unselectedColor,
            size: 22,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CreateOrbButton extends StatelessWidget {
  const _CreateOrbButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF35C8FF), Color(0xFFFF6B4A)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B4A).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Create Post',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(50, 50),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
        ),
        icon: const Icon(Icons.add_rounded, size: 25),
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
      return const Color(0xFF35C8FF);
    case AppBottomNavTab.profile:
      return const Color(0xFFFF6B4A);
  }
}
