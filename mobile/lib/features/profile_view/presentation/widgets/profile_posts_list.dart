import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/presentation/profile_post_detail_screen.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/login_style_controller.dart';
import 'package:provider/provider.dart';

class ProfilePostsList extends StatelessWidget {
  const ProfilePostsList({
    super.key,
    required this.posts,
    required this.canLoadMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onRetryLoadMore,
    required this.onViewComments,
    required this.onAddComment,
    this.hasLoadMoreError = false,
  });

  final List<ProfilePostSummary> posts;
  final bool canLoadMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryLoadMore;
  final Future<List<ProfilePostComment>> Function(String postId) onViewComments;
  final Future<ProfilePostComment?> Function(String postId, String content)
  onAddComment;
  final bool hasLoadMoreError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = context.watch<LoginStyleController>().style;
    final palette = _ProfilePostsPalette.forStyle(style);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (posts.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DemoSongPostCard(palette: palette),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  l10n.profileEmptyPostsMessage,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final post = posts[index];
              final textAttachment = _firstTextAttachment(post.attachments);
              final spotifyAttachment = _firstSpotifyAttachment(
                post.attachments,
              );
              final tileTone = _storyTone(index);

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openPostDetail(context, post, posts, index),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.flash_on_rounded,
                              size: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: tileTone.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF1A1A1A,
                                ).withValues(alpha: 0.10),
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Builder(
                              builder: (context) {
                                if (spotifyAttachment != null) {
                                  return const Center(
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: Color(0xFF1DB954),
                                      size: 34,
                                    ),
                                  );
                                }
                                if (textAttachment != null) {
                                  return Text(
                                    textAttachment.content!,
                                    maxLines: 7,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  );
                                }
                                return Icon(
                                  Icons.camera_alt_rounded,
                                  color: const Color(0xFF4A4A4A),
                                  size: 30,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _shortDate(post.createdAt),
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF5B5B5B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        if (hasLoadMoreError)
          Center(
            child: Semantics(
              label: l10n.retryButton,
              child: TextButton(
                onPressed: onRetryLoadMore,
                child: Text(l10n.retryButton),
              ),
            ),
          )
        else if (isLoadingMore)
          const Center(child: CircularProgressIndicator())
        else if (canLoadMore)
          Center(
            child: Semantics(
              label: l10n.loadMorePostsButton,
              child: TextButton(
                onPressed: onLoadMore,
                child: Text(l10n.loadMorePostsButton),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openPostDetail(
    BuildContext context,
    ProfilePostSummary post,
    List<ProfilePostSummary> allPosts,
    int initialIndex,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfilePostDetailScreen(
          posts: allPosts,
          initialIndex: initialIndex,
          loadComments: onViewComments,
          addComment: onAddComment,
        ),
      ),
    );
  }

  PostAttachmentSummary? _firstTextAttachment(
    List<PostAttachmentSummary> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.type != 'text') continue;
      final content = attachment.content?.trim();
      if (content != null && content.isNotEmpty) {
        return attachment;
      }
    }
    return null;
  }

  PostAttachmentSummary? _firstSpotifyAttachment(
    List<PostAttachmentSummary> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.type != 'spotify_link') continue;
      final url = attachment.url?.trim();
      if (url != null && url.isNotEmpty) {
        return attachment;
      }
    }
    return null;
  }

  Color _storyTone(int index) {
    const tones = [
      Color(0xFF2B2D42),
      Color(0xFF273469),
      Color(0xFF2A2A72),
      Color(0xFF3A3A3A),
    ];
    return tones[index % tones.length];
  }

  String _shortDate(DateTime value) {
    return '${value.month}/${value.day}/${value.year}';
  }
}

class _DemoSongPostCard extends StatelessWidget {
  const _DemoSongPostCard({required this.palette});

  final _ProfilePostsPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = palette.cardColor;
    final borderColor = palette.cardBorderColor;
    final titleTextColor = palette.titleTextColor;
    final mutedTextColor = palette.mutedTextColor;
    final bodyTextColor = palette.bodyTextColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Echo Demo',
                      style: textTheme.bodyMedium?.copyWith(
                        color: titleTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Demo song post',
                      style: textTheme.bodySmall?.copyWith(
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.demoBadgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'DEMO',
                  style: textTheme.labelSmall?.copyWith(
                    color: palette.demoBadgeTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Now playing: Midnight City - M83',
            style: textTheme.bodyMedium?.copyWith(color: bodyTextColor),
          ),
          const SizedBox(height: 10),
          Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B7CFA), Color(0xFF7C3AED)],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePostsPalette {
  const _ProfilePostsPalette({
    required this.cardColor,
    required this.cardBorderColor,
    required this.titleTextColor,
    required this.mutedTextColor,
    required this.bodyTextColor,
    required this.attachmentChipColor,
    required this.demoBadgeColor,
    required this.demoBadgeTextColor,
  });

  final Color cardColor;
  final Color cardBorderColor;
  final Color titleTextColor;
  final Color mutedTextColor;
  final Color bodyTextColor;
  final Color attachmentChipColor;
  final Color demoBadgeColor;
  final Color demoBadgeTextColor;

  static _ProfilePostsPalette forStyle(LoginStyleVariant style) {
    switch (style) {
      case LoginStyleVariant.modernLight:
        return const _ProfilePostsPalette(
          cardColor: Colors.white,
          cardBorderColor: Color(0xFFDDE4F5),
          titleTextColor: Color(0xFF111827),
          mutedTextColor: Color(0xFF667085),
          bodyTextColor: Color(0xFF111827),
          attachmentChipColor: Color(0xFFF0F3FA),
          demoBadgeColor: Color(0xFFE9EDFF),
          demoBadgeTextColor: Color(0xFF3E4CB3),
        );
      case LoginStyleVariant.darkMode:
        return const _ProfilePostsPalette(
          cardColor: Color(0xFF171D29),
          cardBorderColor: Color(0xFF2E3647),
          titleTextColor: Color(0xFFEAF0FF),
          mutedTextColor: Color(0xFFAEB9CC),
          bodyTextColor: Color(0xFFEAF0FF),
          attachmentChipColor: Color(0xFF222B3B),
          demoBadgeColor: Color(0xFF2A3550),
          demoBadgeTextColor: Color(0xFFD7E2FF),
        );
      case LoginStyleVariant.gradientVibe:
        return _ProfilePostsPalette(
          cardColor: Colors.white.withValues(alpha: 0.16),
          cardBorderColor: Colors.white.withValues(alpha: 0.30),
          titleTextColor: Colors.white,
          mutedTextColor: Colors.white70,
          bodyTextColor: Colors.white,
          attachmentChipColor: Colors.white.withValues(alpha: 0.20),
          demoBadgeColor: Colors.white.withValues(alpha: 0.22),
          demoBadgeTextColor: Colors.white,
        );
      case LoginStyleVariant.glassmorphism:
        return _ProfilePostsPalette(
          cardColor: Colors.white.withValues(alpha: 0.30),
          cardBorderColor: Colors.white.withValues(alpha: 0.48),
          titleTextColor: Colors.white,
          mutedTextColor: Colors.white70,
          bodyTextColor: Colors.white,
          attachmentChipColor: Colors.white.withValues(alpha: 0.34),
          demoBadgeColor: const Color(0xFF7A62FF),
          demoBadgeTextColor: Colors.white,
        );
      case LoginStyleVariant.minimalClean:
        return const _ProfilePostsPalette(
          cardColor: Colors.white,
          cardBorderColor: Color(0xFFD5D9E2),
          titleTextColor: Color(0xFF111827),
          mutedTextColor: Color(0xFF6B7280),
          bodyTextColor: Color(0xFF111827),
          attachmentChipColor: Color(0xFFF3F4F7),
          demoBadgeColor: Color(0xFF111111),
          demoBadgeTextColor: Colors.white,
        );
    }
  }
}
