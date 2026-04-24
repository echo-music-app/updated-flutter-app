import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/themes/login_style_controller.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/tab_accent_strip.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:provider/provider.dart';

const _kSurfaceRadius = 20.0;
const _kCardRadius = 22.0;
const _kChipRadius = 999.0;
const _kPanelPadding = 14.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeStyle = context.watch<LoginStyleController>().style;
    final palette = _HomeFeedPalette.forStyle(activeStyle);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: const AppTopNavLeading(),
        title: Text('Home Feed', style: TextStyle(color: palette.primaryText)),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: palette.primaryText,
            ),
            tooltip: 'Notifications',
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.backgroundGradient,
          ),
        ),
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => Column(
            children: [
              const TabAccentStrip(tab: AppBottomNavTab.home),
              _HomeHeroStrip(
                palette: palette,
                activeCategory: viewModel.activeCategory,
                postCount: viewModel.filteredPosts.length,
                musicPostCount: viewModel.filteredPosts
                    .where((post) => post.spotifyUrl != null)
                    .length,
                peopleCount: viewModel.filteredPosts
                    .map((post) => post.userId)
                    .toSet()
                    .length,
              ),
              const SizedBox(height: AppSpacing.sm),
              _HomeCategoryTabs(
                palette: palette,
                activeCategory: viewModel.activeCategory,
                onSelected: viewModel.setCategory,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildBody(context, l10n, palette)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentTab: AppBottomNavTab.home,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    _HomeFeedPalette palette,
  ) {
    final posts = viewModel.filteredPosts;
    switch (viewModel.state) {
      case HomeScreenState.loading:
        return Center(
          child: CircularProgressIndicator(color: palette.actionAccent),
        );
      case HomeScreenState.empty:
        return Center(
          child: _StatusCard(
            palette: palette,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.emptyMessage,
                style: TextStyle(color: palette.primaryText),
              ),
            ),
          ),
        );
      case HomeScreenState.error:
        return Center(
          child: _StatusCard(
            palette: palette,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.errorMessage,
                    style: TextStyle(color: palette.primaryText),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label: l10n.retryButton,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.actionAccent,
                        foregroundColor: palette.onActionAccent,
                      ),
                      onPressed: viewModel.loadFeed,
                      child: Text(l10n.retryButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case HomeScreenState.data:
        if (posts.isEmpty) {
          return Center(
            child: _StatusCard(
              palette: palette,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No posts yet in ${_categoryLabel(viewModel.activeCategory)}',
                  style: TextStyle(color: palette.primaryText),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: viewModel.loadFeed,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FeedDigestCard(
                    palette: palette,
                    totalPosts: posts.length,
                    musicPosts: posts
                        .where((post) => post.spotifyUrl != null)
                        .length,
                    totalEngagement: posts.fold<int>(
                      0,
                      (sum, post) => sum + post.likeCount + post.commentCount,
                    ),
                  ),
                );
              }
              final postIndex = index - 1;
              final post = posts[postIndex];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: postIndex == posts.length - 1 ? 0 : 12,
                ),
                child: _AnimatedFeedCard(
                  order: postIndex,
                  child: _FeedPostCard(
                    post: post,
                    onToggleLike: () => viewModel.toggleLike(post.id),
                    onLoadComments: () => viewModel.loadComments(post.id),
                    onAddComment: (text) => viewModel.addComment(post.id, text),
                    onShare: () => _sharePost(context, post),
                    palette: palette,
                  ),
                ),
              );
            },
          ),
        );
    }
  }

  void _sharePost(BuildContext context, HomeFeedPost post) {
    final shareText =
        post.spotifyUrl ?? post.text ?? 'Check this post from ${post.userName}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied. Share it anywhere.')),
    );
  }
}

class _HomeHeroStrip extends StatelessWidget {
  const _HomeHeroStrip({
    required this.palette,
    required this.activeCategory,
    required this.postCount,
    required this.musicPostCount,
    required this.peopleCount,
  });

  final _HomeFeedPalette palette;
  final HomeFeedCategory activeCategory;
  final int postCount;
  final int musicPostCount;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_kPanelPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(
            color: palette.onActionAccent.withValues(alpha: 0.14),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.actionAccent.withValues(alpha: 0.95),
              palette.actionAccent.withValues(alpha: 0.78),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.actionAccent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Campus Discover',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.onActionAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _categoryLabel(activeCategory),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: palette.onActionAccent.withValues(alpha: 0.84),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: palette.onActionAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(_kChipRadius),
              ),
              child: Text(
                'Now Trending',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: palette.onActionAccent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'Posts',
                    value: postCount,
                    icon: Icons.dynamic_feed_rounded,
                    color: palette.onActionAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroMetric(
                    label: 'Music',
                    value: musicPostCount,
                    icon: Icons.music_note_rounded,
                    color: palette.onActionAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroMetric(
                    label: 'People',
                    value: peopleCount,
                    icon: Icons.people_alt_rounded,
                    color: palette.onActionAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedDigestCard extends StatelessWidget {
  const _FeedDigestCard({
    required this.palette,
    required this.totalPosts,
    required this.musicPosts,
    required this.totalEngagement,
  });

  final _HomeFeedPalette palette;
  final int totalPosts;
  final int musicPosts;
  final int totalEngagement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(_kSurfaceRadius),
        border: Border.all(color: palette.cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_kPanelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.actionAccent.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: palette.actionAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today in your feed',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A quick social pulse for your current filter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DigestMetricTile(
                    label: 'Posts',
                    value: '$totalPosts',
                    palette: palette,
                    icon: Icons.dynamic_feed_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DigestMetricTile(
                    label: 'Music',
                    value: '$musicPosts',
                    palette: palette,
                    icon: Icons.music_note_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DigestMetricTile(
                    label: 'Engagement',
                    value: '$totalEngagement',
                    palette: palette,
                    icon: Icons.local_fire_department_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestMetricTile extends StatelessWidget {
  const _DigestMetricTile({
    required this.label,
    required this.value,
    required this.palette,
    required this.icon,
  });

  final String label;
  final String value;
  final _HomeFeedPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.secondarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: palette.secondaryText),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedMiniPill extends StatelessWidget {
  const _FeedMiniPill({
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFeedCard extends StatelessWidget {
  const _AnimatedFeedCard({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final beginOffsetY = (order.clamp(0, 6)) * 0.04 + 0.04;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 320 + (order.clamp(0, 8) * 25)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 32 * beginOffsetY),
            child: animatedChild,
          ),
        );
      },
    );
  }
}

class _PostActionChip extends StatefulWidget {
  const _PostActionChip({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
    this.count,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final int? count;

  @override
  State<_PostActionChip> createState() => _PostActionChipState();
}

class _PostActionChipState extends State<_PostActionChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final countText = widget.count != null ? ' ${widget.count!}' : '';
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kChipRadius),
          boxShadow: _pressed
              ? const []
              : [
                  BoxShadow(
                    color: widget.foregroundColor.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_kChipRadius),
          onTap: widget.onPressed,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(_kChipRadius),
              border: Border.all(
                color: widget.foregroundColor.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: widget.foregroundColor),
                const SizedBox(width: 6),
                Text(
                  '${widget.label}$countText',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: widget.foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.onToggleLike,
    required this.onLoadComments,
    required this.onAddComment,
    required this.onShare,
    required this.palette,
  });

  final HomeFeedPost post;
  final Future<void> Function() onToggleLike;
  final Future<List<HomeFeedComment>> Function() onLoadComments;
  final Future<HomeFeedComment?> Function(String text) onAddComment;
  final void Function() onShare;
  final _HomeFeedPalette palette;

  void _openAuthorProfile(BuildContext context) {
    context.push('${Routes.profile}/${Uri.encodeComponent(post.userId)}');
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: palette.primaryText,
    );
    final subtleTextColor = palette.secondaryText;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardColor,
        border: Border.all(color: palette.cardBorderColor),
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadowColor,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_kPanelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  radius: 22,
                  imageProvider: post.userAvatarUrl != null
                      ? NetworkImage(post.userAvatarUrl!)
                      : null,
                  backgroundColor: _seedColor(post.userId, shift: 0),
                  fallbackText: post.userInitials,
                  fallbackTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
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
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _PrivacyBadge(
                            privacy: post.privacy,
                            palette: palette,
                          ),
                          _FeedMiniPill(
                            icon: Icons.local_fire_department_rounded,
                            text: '${post.likeCount + post.commentCount} pulse',
                            foreground: subtleTextColor,
                            background: palette.secondarySurface,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onShare,
                  tooltip: 'Share post',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_horiz_rounded, color: subtleTextColor),
                ),
              ],
            ),
            if (post.spotifyUrl != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.secondarySurface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: palette.cardBorderColor.withValues(alpha: 0.75),
                  ),
                ),
                child: Row(
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Spotify Track',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: subtleTextColor),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              backgroundColor: palette.cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () {},
                            icon: Icon(
                              Icons.play_arrow_rounded,
                              color: palette.primaryText,
                            ),
                            label: Text(
                              'Play',
                              style: TextStyle(color: palette.primaryText),
                            ),
                          ),
                          Text(
                            _spotifyLabel(post.spotifyUrl!),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: subtleTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (post.text != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: palette.secondarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  post.text!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: palette.primaryText),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Divider(
              height: 1,
              color: palette.cardBorderColor.withValues(alpha: 0.9),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PostActionChip(
                  icon: post.currentUserLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: 'Like',
                  count: post.likeCount,
                  foregroundColor: post.currentUserLiked
                      ? const Color(0xFFFF4D67)
                      : palette.secondaryText,
                  backgroundColor: palette.secondarySurface,
                  onPressed: () => onToggleLike(),
                ),
                _PostActionChip(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comment',
                  count: post.commentCount,
                  foregroundColor: palette.secondaryText,
                  backgroundColor: palette.secondarySurface,
                  onPressed: () => _openCommentsSheet(context),
                ),
                _PostActionChip(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  foregroundColor: palette.secondaryText,
                  backgroundColor: palette.secondarySurface,
                  onPressed: onShare,
                ),
              ],
            ),
            if (post.comments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...post.comments
                  .take(2)
                  .map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${comment.authorName}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.primaryText,
                              ),
                            ),
                            TextSpan(
                              text: comment.text,
                              style: TextStyle(color: palette.primaryText),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCommentsSheet(BuildContext context) async {
    final initialComments = await onLoadComments();
    if (!context.mounted) return;
    final controller = TextEditingController();
    final submitted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final comments = [...initialComments];

        void submitComment(String rawValue) {
          final text = rawValue.trim();
          if (text.isEmpty) return;
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop(text);
        }

        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (comments.isEmpty)
                Text(
                  'No comments yet. Be the first one.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    separatorBuilder: (_, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${comment.authorName}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: comment.text),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Write a comment',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: () => submitComment(controller.text),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: submitComment,
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (submitted == null) return;
    await onAddComment(submitted);
  }
}

class _HomeCategoryTabs extends StatelessWidget {
  const _HomeCategoryTabs({
    required this.activeCategory,
    required this.onSelected,
    required this.palette,
  });

  final HomeFeedCategory activeCategory;
  final ValueChanged<HomeFeedCategory> onSelected;
  final _HomeFeedPalette palette;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: HomeFeedCategory.values
            .map((category) {
              final isActive = category == activeCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _categoryIcon(category),
                        size: 14,
                        color: isActive
                            ? palette.tabActiveText
                            : palette.tabText,
                      ),
                      const SizedBox(width: 6),
                      Text(_categoryLabel(category)),
                    ],
                  ),
                  selected: isActive,
                  labelStyle: TextStyle(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? palette.tabActiveText : palette.tabText,
                  ),
                  selectedColor: palette.tabActiveBackground,
                  backgroundColor: palette.tabBackground,
                  side: BorderSide(color: palette.tabBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kChipRadius),
                  ),
                  onSelected: (_) => onSelected(category),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.palette, required this.child});

  final _HomeFeedPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(_kSurfaceRadius),
        border: Border.all(color: palette.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadowColor,
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HomeFeedPalette {
  const _HomeFeedPalette({
    required this.backgroundGradient,
    required this.appBarColor,
    required this.primaryText,
    required this.secondaryText,
    required this.cardColor,
    required this.cardBorderColor,
    required this.cardShadowColor,
    required this.secondarySurface,
    required this.actionAccent,
    required this.onActionAccent,
    required this.tabBackground,
    required this.tabBorder,
    required this.tabText,
    required this.tabActiveBackground,
    required this.tabActiveText,
  });

  final List<Color> backgroundGradient;
  final Color appBarColor;
  final Color primaryText;
  final Color secondaryText;
  final Color cardColor;
  final Color cardBorderColor;
  final Color cardShadowColor;
  final Color secondarySurface;
  final Color actionAccent;
  final Color onActionAccent;
  final Color tabBackground;
  final Color tabBorder;
  final Color tabText;
  final Color tabActiveBackground;
  final Color tabActiveText;

  static _HomeFeedPalette forStyle(LoginStyleVariant style) {
    switch (style) {
      case LoginStyleVariant.modernLight:
        return _HomeFeedPalette(
          backgroundGradient: const [Color(0xFFF2F3F8), Color(0xFFEFF1F7)],
          appBarColor: const Color(0xFFF2F3F8),
          primaryText: const Color(0xFF111827),
          secondaryText: const Color(0xFF5B6678),
          cardColor: Colors.white,
          cardBorderColor: const Color(0xFFE2E8F2),
          cardShadowColor: const Color(0x140F172A),
          secondarySurface: const Color(0xFFF5F7FB),
          actionAccent: const Color(0xFF5F46FF),
          onActionAccent: Colors.white,
          tabBackground: const Color(0xFFE8ECF5),
          tabBorder: const Color(0xFFD7DFEB),
          tabText: const Color(0xFF546072),
          tabActiveBackground: const Color(0xFF5F46FF),
          tabActiveText: Colors.white,
        );
      case LoginStyleVariant.darkMode:
        return _HomeFeedPalette(
          backgroundGradient: const [Color(0xFF0E1230), Color(0xFF090D24)],
          appBarColor: const Color(0xFF0E1230),
          primaryText: Colors.white,
          secondaryText: const Color(0xFF9BA7BA),
          cardColor: const Color(0xFF11162E),
          cardBorderColor: const Color(0xFF222A36),
          cardShadowColor: const Color(0x4D01030E),
          secondarySurface: const Color(0xFF1A203A),
          actionAccent: const Color(0xFF5F46FF),
          onActionAccent: Colors.white,
          tabBackground: const Color(0xFF171E3A),
          tabBorder: const Color(0xFF2D3A52),
          tabText: const Color(0xFFAFB9CC),
          tabActiveBackground: const Color(0xFF5F46FF),
          tabActiveText: Colors.white,
        );
      case LoginStyleVariant.gradientVibe:
        return _HomeFeedPalette(
          backgroundGradient: const [Color(0xFF6C4BFF), Color(0xFFF26A70)],
          appBarColor: const Color(0x336C4BFF),
          primaryText: Colors.white,
          secondaryText: Colors.white70,
          cardColor: Colors.white.withValues(alpha: 0.10),
          cardBorderColor: Colors.white.withValues(alpha: 0.24),
          cardShadowColor: const Color(0x33070B28),
          secondarySurface: Colors.white.withValues(alpha: 0.15),
          actionAccent: Colors.white,
          onActionAccent: const Color(0xFF6A4CFF),
          tabBackground: Colors.white.withValues(alpha: 0.12),
          tabBorder: Colors.white.withValues(alpha: 0.24),
          tabText: Colors.white70,
          tabActiveBackground: Colors.white,
          tabActiveText: const Color(0xFF6A4CFF),
        );
      case LoginStyleVariant.glassmorphism:
        return _HomeFeedPalette(
          backgroundGradient: const [Color(0xFFDCD4F5), Color(0xFFC8BEEB)],
          appBarColor: const Color(0x40FFFFFF),
          primaryText: Colors.white,
          secondaryText: Colors.white70,
          cardColor: Colors.white.withValues(alpha: 0.24),
          cardBorderColor: Colors.white.withValues(alpha: 0.40),
          cardShadowColor: const Color(0x26060A20),
          secondarySurface: Colors.white.withValues(alpha: 0.30),
          actionAccent: const Color(0xFF6A4BFF),
          onActionAccent: Colors.white,
          tabBackground: Colors.white.withValues(alpha: 0.24),
          tabBorder: Colors.white.withValues(alpha: 0.46),
          tabText: const Color(0xFFEAF0FF),
          tabActiveBackground: const Color(0xFF6A4BFF),
          tabActiveText: Colors.white,
        );
      case LoginStyleVariant.minimalClean:
        return _HomeFeedPalette(
          backgroundGradient: const [Color(0xFFF8F8FA), Color(0xFFF4F4F7)],
          appBarColor: const Color(0xFFF8F8FA),
          primaryText: const Color(0xFF111827),
          secondaryText: const Color(0xFF6B7280),
          cardColor: Colors.white,
          cardBorderColor: const Color(0xFFD5D9E2),
          cardShadowColor: const Color(0x110F172A),
          secondarySurface: const Color(0xFFF7F8FB),
          actionAccent: const Color(0xFF090909),
          onActionAccent: Colors.white,
          tabBackground: const Color(0xFFF0F2F6),
          tabBorder: const Color(0xFFD7DFEB),
          tabText: const Color(0xFF6B7280),
          tabActiveBackground: const Color(0xFF111111),
          tabActiveText: Colors.white,
        );
    }
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.privacy, required this.palette});

  final PostPrivacy privacy;
  final _HomeFeedPalette palette;

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
        color: palette.secondarySurface,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: palette.secondaryText),
      ),
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
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
      ),
      child: const SizedBox(
        height: 92,
        width: 92,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
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

String _categoryLabel(HomeFeedCategory category) {
  return switch (category) {
    HomeFeedCategory.ibsFirstYear => 'IBS 1st Year',
    HomeFeedCategory.ibsCorporateFinance => 'IBS Corporate Finance',
    HomeFeedCategory.budapest => 'Budapest',
    HomeFeedCategory.friends => 'Friends',
  };
}

IconData _categoryIcon(HomeFeedCategory category) {
  return switch (category) {
    HomeFeedCategory.ibsFirstYear => Icons.school_rounded,
    HomeFeedCategory.ibsCorporateFinance => Icons.account_balance_rounded,
    HomeFeedCategory.budapest => Icons.location_city_rounded,
    HomeFeedCategory.friends => Icons.group_rounded,
  };
}
