import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/login_style_controller.dart';
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
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
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
      messenger.showSnackBar(
        SnackBar(content: Text('Token refresh failed: $e')),
      );
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
    final loginStyleController = hostContext.watch<LoginStyleController>();
    final isDarkMode = themeController.isDarkMode;
    final panelWidth = MediaQuery.of(context).size.width * 0.82;
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          elevation: 12,
          child: SizedBox(
            width: panelWidth.clamp(260, 340),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  hostContext,
                ).colorScheme.surfaceContainerLowest.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(24),
                ),
                border: Border.all(
                  color: Theme.of(
                    hostContext,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(
                            hostContext,
                          ).colorScheme.primary.withValues(alpha: 0.26),
                          Theme.of(
                            hostContext,
                          ).colorScheme.secondary.withValues(alpha: 0.20),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: const Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'Echo Menu',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: const Icon(Icons.person_rounded),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.of(context).pop();
                      hostContext.go(Routes.profile);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(
                      isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                    title: Text(isDarkMode ? 'Light mode' : 'Dark mode'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await themeController.toggle();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Login theme',
                      style: TextStyle(
                        color: Theme.of(hostContext).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<LoginStyleVariant>(
                      initialValue: loginStyleController.style,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: LoginStyleVariant.values
                          .map(
                            (style) => DropdownMenuItem<LoginStyleVariant>(
                              value: style,
                              child: Text(_loginStyleLabel(style)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await loginStyleController.setStyle(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Refresh token'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _refreshSession();
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Logout'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _logout();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _loginStyleLabel(LoginStyleVariant style) {
  switch (style) {
    case LoginStyleVariant.modernLight:
      return 'Modern Light';
    case LoginStyleVariant.darkMode:
      return 'Dark Mode';
    case LoginStyleVariant.gradientVibe:
      return 'Gradient Vibe';
    case LoginStyleVariant.glassmorphism:
      return 'Glassmorphism';
    case LoginStyleVariant.minimalClean:
      return 'Minimal Clean';
  }
}
