import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Open menu',
          onPressed: () => showAppSidebar(context),
        ),
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () => context.go(Routes.notifications),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => _buildBody(context, l10n),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentTab: AppBottomNavTab.home,
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    switch (viewModel.state) {
      case HomeScreenState.loading:
        return const Center(child: CircularProgressIndicator());
      case HomeScreenState.empty:
        return Center(child: Text(l10n.emptyMessage));
      case HomeScreenState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorMessage),
              SizedBox(height: AppSpacing.md),
              Semantics(
                label: l10n.retryButton,
                child: ElevatedButton(
                  onPressed: viewModel.loadFeed,
                  child: Text(l10n.retryButton),
                ),
              ),
            ],
          ),
        );
      case HomeScreenState.data:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          itemCount: viewModel.posts.length,
          separatorBuilder: (context, _) =>
              const Divider(height: AppSpacing.xl),
          itemBuilder: (context, index) {
            final post = viewModel.posts[index];
            return _FeedPostCard(post: post);
          },
        );
    }
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.post});

  final HomeFeedPost post;

  void _openAuthorProfile(BuildContext context) {
    context.go('${Routes.profile}/${Uri.encodeComponent(post.userId)}');
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final subtleTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: post.userAvatarUrl != null
                  ? NetworkImage(post.userAvatarUrl!)
                  : null,
              backgroundColor: _seedColor(post.userId, shift: 0),
              child: post.userAvatarUrl == null
                  ? Text(
                      post.userInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    label: 'Open ${post.userName} profile',
                    child: InkWell(
                      onTap: () => _openAuthorProfile(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        child: Text(post.userName, style: titleStyle),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        post.userHandle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: subtleTextColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PrivacyBadge(privacy: post.privacy),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (post.spotifyUrl != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackArt(
                topColor: _seedColor(post.id, shift: 11),
                bottomColor: _seedColor(post.id, shift: 19),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _spotifyTitle(post.spotifyUrl!),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Spotify',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: subtleTextColor),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Spotify'),
                    ),
                    Text(
                      _spotifyLabel(post.spotifyUrl!),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtleTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (post.text != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(post.text!, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ],
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.privacy});

  final PostPrivacy privacy;

  @override
  Widget build(BuildContext context) {
    final label = switch (privacy) {
      PostPrivacy.public => 'Public',
      PostPrivacy.friendsOnly => 'Friends only',
      PostPrivacy.onlyMe => 'Private',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _TrackArt extends StatelessWidget {
  const _TrackArt({required this.topColor, required this.bottomColor});

  final Color topColor;
  final Color bottomColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
      ),
      child: SizedBox(
        height: 92,
        width: 92,
        child: Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _seedColor(String seed, {required int shift}) {
  final hash = seed.hashCode;
  final r = 90 + ((hash >> (shift + 2)) & 0x4F);
  final g = 70 + ((hash >> (shift + 5)) & 0x5F);
  final b = 100 + ((hash >> (shift + 8)) & 0x4F);
  return Color.fromARGB(255, r, g, b);
}

String _spotifyTitle(String url) {
  final uri = Uri.tryParse(url);
  final segments = uri?.pathSegments ?? const <String>[];
  if (segments.length >= 2 && segments[0] == 'track') {
    final trackId = segments[1];
    final shortId = trackId.length <= 10 ? trackId : trackId.substring(0, 10);
    return 'Track $shortId';
  }
  return 'Spotify Track';
}

String _spotifyLabel(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host;
  final path = uri.path;
  return '$host$path';
}

extension on HomeFeedPost {
  String get userInitials => userName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
