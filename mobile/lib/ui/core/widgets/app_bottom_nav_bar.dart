import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';

enum AppBottomNavTab { home, search, profile }

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, this.currentTab});

  final AppBottomNavTab? currentTab;

  void _navigateTo(BuildContext context, AppBottomNavTab tab) {
    if (tab == currentTab) return;
    switch (tab) {
      case AppBottomNavTab.home:
        context.go(Routes.home);
      case AppBottomNavTab.search:
        context.go(Routes.search);
      case AppBottomNavTab.profile:
        context.go(Routes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
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
