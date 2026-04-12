import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  Future<void> _refreshSession(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthRepository>();
    try {
      final refreshed = await auth.refreshAccessToken();
      if (!context.mounted) return;
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
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Token refresh failed: $e')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthRepository>();
    try {
      await auth.logout();
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Logged out.')));
    } on Exception catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh token',
            onPressed: () => _refreshSession(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => _buildBody(context, l10n),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    switch (viewModel.state) {
      case HomeScreenState.loading:
        return const CircularProgressIndicator();
      case HomeScreenState.empty:
        return Text(l10n.emptyMessage);
      case HomeScreenState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.errorMessage),
            SizedBox(height: AppSpacing.md),
            Semantics(
              label: l10n.retryButton,
              child: ElevatedButton(
                onPressed: null,
                child: Text(l10n.retryButton),
              ),
            ),
          ],
        );
      case HomeScreenState.data:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.homeTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: AppSpacing.lg),
            const Image(
              image: AssetImage('assets/images/logo_light.png'),
              height: 120,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => context.go(Routes.player),
              child: Text(l10n.openPlayer),
            ),
            SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => context.go(Routes.playerWebView),
              child: Text(l10n.openWebViewPlayer),
            ),
            SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => context.go(Routes.profile),
              child: Text(l10n.myProfileTitle),
            ),
            SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => context.go(Routes.search),
              child: Text(l10n.searchOpenLabel),
            ),
          ],
        );
    }
  }
}
