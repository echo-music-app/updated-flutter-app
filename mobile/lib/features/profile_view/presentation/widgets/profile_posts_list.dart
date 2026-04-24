import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/presentation/profile_post_detail_screen.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cardColor = colorScheme.surfaceContainerLowest;
    final borderColor = colorScheme.outlineVariant;
    final mutedTextColor = colorScheme.onSurfaceVariant;
    final bodyTextColor = colorScheme.onSurface;
    final titleTextColor = colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (posts.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DemoSongPostCard(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  l10n.profileEmptyPostsMessage,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final textAttachment = _firstTextAttachment(post.attachments);
              final spotifyAttachment = _firstSpotifyAttachment(
                post.attachments,
              );
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openPostDetail(context, post, posts, index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
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
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            child: Text(
                              post.userId.isNotEmpty
                                  ? post.userId[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User ${_safeShortId(post.userId)}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: titleTextColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _humanDate(post.createdAt),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: mutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _privacyPill(
                            context: context,
                            label: _privacyCaption(post.privacy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (textAttachment != null)
                        Text(
                          textAttachment.content!,
                          style: textTheme.bodyLarge?.copyWith(
                            color: bodyTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (spotifyAttachment != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.58,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.music_note_rounded,
                                size: 18,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  spotifyAttachment.url!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (textAttachment == null && spotifyAttachment == null)
                        Container(
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.22),
                                colorScheme.tertiary.withValues(alpha: 0.14),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Campus story update',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${post.attachments.length} attachment(s)',
                              style: textTheme.labelMedium?.copyWith(
                                color: mutedTextColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openCommentsSheet(context, post),
                            icon: const Icon(
                              Icons.mode_comment_outlined,
                              size: 18,
                            ),
                            label: const Text('Comments'),
                          ),
                        ],
                      ),
                    ],
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

  Widget _privacyPill({required BuildContext context, required String label}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
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

  String _humanDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _privacyCaption(String privacy) {
    return privacy.toUpperCase();
  }

  String _safeShortId(String id) {
    if (id.length <= 6) return id;
    return id.substring(0, 6);
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

  Future<void> _openCommentsSheet(
    BuildContext context,
    ProfilePostSummary post,
  ) async {
    final comments = await onViewComments(post.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
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
              const SizedBox(height: 12),
              if (comments.isEmpty)
                Text(
                  'No comments yet.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
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
                              text: '${comment.username}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: comment.content),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DemoSongPostCard extends StatelessWidget {
  const _DemoSongPostCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = colorScheme.surface;
    final borderColor = colorScheme.outlineVariant;
    final titleTextColor = colorScheme.onSurface;
    final mutedTextColor = colorScheme.onSurfaceVariant;
    final bodyTextColor = colorScheme.onSurface;
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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'DEMO',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
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
