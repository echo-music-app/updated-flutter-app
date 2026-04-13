import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/theme_mode_controller.dart';
import 'package:provider/provider.dart';

Future<void> showAppSidebar(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close sidebar',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _SidebarSheet(hostContext: context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: Tween<double>(begin: 0.6, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SidebarSheet extends StatelessWidget {
  const _SidebarSheet({required this.hostContext});

  final BuildContext hostContext;

  Future<void> _refreshSession() async {
    final messenger = ScaffoldMessenger.of(hostContext);
    final auth = hostContext.read<AuthRepository>();
    try {
      final refreshed = await auth.refreshAccessToken();
      if (!hostContext.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            refreshed == null
                ? 'Session expired. Please sign in again.'
                : 'Session token refreshed.',
          ),
        ),
      );
    } on Exception catch (e) {
      if (!hostContext.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Token refresh failed: $e')));
    }
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(hostContext);
    final auth = hostContext.read<AuthRepository>();
    try {
      await auth.logout();
      if (!hostContext.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            auth.lastLogoutWasLocalOnly
                ? 'Logged out locally. Server was unreachable.'
                : 'Logged out.',
            ),
        ),
      );
      hostContext.go(Routes.login);
    } on Exception catch (e) {
      if (!hostContext.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = hostContext.watch<ThemeModeController>();
    final isDarkMode = themeController.isDarkMode;
    final panelWidth = MediaQuery.of(context).size.width * 0.82;
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Theme.of(hostContext).colorScheme.surface,
          elevation: 12,
          child: SizedBox(
            width: panelWidth.clamp(260, 340),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Echo Menu',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                  title: Text(isDarkMode ? 'Light mode' : 'Dark mode'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await themeController.toggle();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Refresh token'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _refreshSession();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _logout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
