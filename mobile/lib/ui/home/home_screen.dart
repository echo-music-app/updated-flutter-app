import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/home/home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const palette = _HomePalette();

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final posts = viewModel.filteredPosts;
            final leadPost = posts.isNotEmpty ? posts.first : null;

            return Column(
              children: [
                _HomeHeader(palette: palette, leadPost: leadPost),
                _HomeCategoryTabs(
                  activeCategory: viewModel.activeCategory,
                  onSelected: viewModel.setCategory,
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildBody(context, l10n, palette, posts)),
              ],
            );
          },
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
    _HomePalette palette,
    List<HomeFeedPost> posts,
  ) {
    switch (viewModel.state) {
      case HomeScreenState.loading:
        return Center(child: CircularProgressIndicator(color: palette.accent));
      case HomeScreenState.error:
        return Center(
          child: _StateCard(
            palette: palette,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.errorMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: viewModel.loadFeed,
                    child: Text(l10n.retryButton),
                  ),
                ],
              ),
            ),
          ),
        );
      case HomeScreenState.empty:
      case HomeScreenState.data:
        return RefreshIndicator(
          color: palette.accent,
          backgroundColor: palette.surface,
          onRefresh: viewModel.loadFeed,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            children: [
              if (posts.isNotEmpty)
                _HomePostCard(
                  post: posts.first,
                  onToggleLike: () => viewModel.toggleLike(posts.first.id),
                  onLoadComments: () => viewModel.loadComments(posts.first.id),
                  onAddComment: (text) =>
                      viewModel.addComment(posts.first.id, text),
                  onShare: () => _sharePost(context, posts.first),
                )
              else
                _StateCard(
                  palette: palette,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No posts yet in ${_categoryLabel(viewModel.activeCategory)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (posts.length > 1) ...[
                const SizedBox(height: 10),
                ...posts
                    .skip(1)
                    .map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HomePostCard(
                          post: post,
                          onToggleLike: () => viewModel.toggleLike(post.id),
                          onLoadComments: () => viewModel.loadComments(post.id),
                          onAddComment: (text) =>
                              viewModel.addComment(post.id, text),
                          onShare: () => _sharePost(context, post),
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 2),
              const _TalentSpotlightCard(),
            ],
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.palette, required this.leadPost});

  final _HomePalette palette;
  final HomeFeedPost? leadPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.surface.withValues(alpha: 0.92),
            palette.surface.withValues(alpha: 0.76),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          AppAvatar(
            radius: 18,
            imageProvider: leadPost?.userAvatarUrl != null
                ? NetworkImage(leadPost!.userAvatarUrl!)
                : null,
            backgroundColor: const Color(0xFF2B3550),
            fallbackText: leadPost?.userInitials ?? 'HF',
            fallbackTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Home Feed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40 / 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
            onPressed: () => context.push(Routes.notifications),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
    );
  }
}

class _HomeCategoryTabs extends StatelessWidget {
  const _HomeCategoryTabs({
    required this.activeCategory,
    required this.onSelected,
  });

  final HomeFeedCategory activeCategory;
  final ValueChanged<HomeFeedCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: HomeFeedCategory.values.length + 1,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isGlobal = index == HomeFeedCategory.values.length;
          if (isGlobal) {
            return _CategoryChip(
              label: 'Global',
              icon: Icons.public_rounded,
              selected: false,
              onTap: null,
            );
          }

          final category = HomeFeedCategory.values[index];
          return _CategoryChip(
            label: _categoryLabel(category),
            icon: _categoryIcon(category),
            selected: category == activeCategory,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const [Color(0xFF7429FF), Color(0xFF4B13B3)]
        : const [Color(0xFF302055), Color(0xFF251941)];

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(colors: bg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePostCard extends StatelessWidget {
  const _HomePostCard({
    required this.post,
    required this.onToggleLike,
    required this.onLoadComments,
    required this.onAddComment,
    required this.onShare,
  });

  final HomeFeedPost post;
  final Future<void> Function() onToggleLike;
  final Future<List<HomeFeedComment>> Function() onLoadComments;
  final Future<HomeFeedComment?> Function(String text) onAddComment;
  final void Function() onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE0EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                radius: 18,
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
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171A27),
                      ),
                    ),
                    Text(
                      post.userHandle,
                      style: const TextStyle(
                        color: Color(0xFF666F82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                visualDensity: VisualDensity.compact,
                onPressed: onShare,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          if (post.text != null && post.text!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.text!,
              style: const TextStyle(
                color: Color(0xFF181B27),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MediaTile(
                  colorA: _seedColor(post.id, shift: 8),
                  colorB: _seedColor(post.id, shift: 14),
                  icon: Icons.brush_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MediaTile(
                  colorA: _seedColor(post.id, shift: 2),
                  colorB: _seedColor(post.id, shift: 18),
                  icon: Icons.palette_outlined,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: post.spotifyUrl != null
                    ? const _SpotifyTile()
                    : _MediaTile(
                        colorA: _seedColor(post.id, shift: 5),
                        colorB: _seedColor(post.id, shift: 22),
                        icon: Icons.image_rounded,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CounterAction(
                icon: post.currentUserLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                value: post.likeCount,
                onTap: () => onToggleLike(),
                active: post.currentUserLiked,
              ),
              const SizedBox(width: 16),
              _CounterAction(
                icon: Icons.mode_comment_outlined,
                value: post.commentCount,
                onTap: () => _openCommentsSheet(context),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Share',
                onPressed: onShare,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
        ],
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

class _CounterAction extends StatelessWidget {
  const _CounterAction({
    required this.icon,
    required this.value,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final int value;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFE34D67) : const Color(0xFF1F2333);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.colorA,
    required this.colorB,
    required this.icon,
  });

  final Color colorA;
  final Color colorB;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorA, colorB],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.90),
          size: 28,
        ),
      ),
    );
  }
}

class _SpotifyTile extends StatelessWidget {
  const _SpotifyTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A5A3A), Color(0xFF2B3F2B)],
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                Icons.music_note_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ),
            Spacer(),
            Text(
              'Play on Spotify',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalentSpotlightCard extends StatelessWidget {
  const _TalentSpotlightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE0EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Talent Spotlight',
            style: TextStyle(
              color: Color(0xFF181B27),
              fontWeight: FontWeight.w800,
              fontSize: 22 / 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _SpotlightRow(
            name: 'Marcus J.',
            subtitle: 'Digital Sculptor',
            seed: 'marcus',
          ),
          const SizedBox(height: 8),
          _SpotlightRow(
            name: 'Kiko Lin',
            subtitle: 'Interactive Artist',
            seed: 'kiko',
          ),
        ],
      ),
    );
  }
}

class _SpotlightRow extends StatelessWidget {
  const _SpotlightRow({
    required this.name,
    required this.subtitle,
    required this.seed,
  });

  final String name;
  final String subtitle;
  final String seed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _seedColor(seed, shift: 5),
          child: Text(
            name[0],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF1D2234)),
              children: [
                TextSpan(
                  text: '$name ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: '($subtitle)'),
              ],
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: const BorderSide(color: Color(0xFF5F46FF)),
          ),
          child: const Text('Follow'),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.palette, required this.child});

  final _HomePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _HomePalette {
  const _HomePalette();

  final Color background = const Color(0xFF0D101A);
  final Color surface = const Color(0xFF151A2A);
  final Color accent = const Color(0xFF5F46FF);
}

Color _seedColor(String seed, {required int shift}) {
  final hash = seed.hashCode;
  final r = 90 + ((hash >> (shift + 2)) & 0x4F);
  final g = 70 + ((hash >> (shift + 5)) & 0x5F);
  final b = 100 + ((hash >> (shift + 8)) & 0x4F);
  return Color.fromARGB(255, r, g, b);
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
