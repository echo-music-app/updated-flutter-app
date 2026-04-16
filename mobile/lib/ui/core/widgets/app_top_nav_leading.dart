import 'package:flutter/material.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';

class AppTopNavLeading extends StatelessWidget {
  const AppTopNavLeading({super.key});

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);
    if (canGoBack) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
      );
    }
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Open menu',
      onPressed: () => showAppSidebar(context),
    );
  }
}
