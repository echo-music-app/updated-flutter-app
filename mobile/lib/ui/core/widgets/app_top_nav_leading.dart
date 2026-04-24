import 'package:flutter/material.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';

class AppTopNavLeading extends StatelessWidget {
  const AppTopNavLeading({super.key});

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);
    Widget button({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            icon: Icon(icon),
            tooltip: tooltip,
            onPressed: onPressed,
          ),
        ),
      );
    }

    if (canGoBack) {
      return button(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
      );
    }
    return button(
      icon: Icons.menu_rounded,
      tooltip: 'Open menu',
      onPressed: () => showAppSidebar(context),
    );
  }
}
