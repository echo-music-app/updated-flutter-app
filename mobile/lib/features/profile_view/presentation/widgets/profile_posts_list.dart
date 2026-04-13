import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

class ProfilePostsList extends StatelessWidget {
  const ProfilePostsList({
    super.key,
    required this.posts,
    required this.canLoadMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onRetryLoadMore,
    this.hasLoadMoreError = false,
  });

  final List<ProfilePostSummary> posts;
  final bool canLoadMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryLoadMore;
  final bool hasLoadMoreError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardColor = isLight ? Colors.white : const Color(0xFF1E232D);
    final borderColor = isLight ? const Color(0xFFE5E7EB) : const Color(0xFF2D3442);
    final mutedTextColor = isLight ? const Color(0xFF6B7280) : const Color(0xFFB8C0D0);
    final bodyTextColor = isLight ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final titleTextColor = isLight ? const Color(0xFF111827) : Colors.white;

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
              return Container(
                key: ValueKey(post.id),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE5E7EB),
                          child: Text(
                            post.userId.isNotEmpty
                                ? post.userId[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF111827),
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
                        const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _privacyCaption(post.privacy),
                      style: textTheme.bodyMedium?.copyWith(
                        color: bodyTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFD6C6B8), Color(0xFFB89B87)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_rounded,
                          size: 34,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${post.attachments.length} attachment(s)',
                      style: textTheme.bodySmall?.copyWith(
                        color: mutedTextColor,
                      ),
                    ),
                  ],
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

  String _humanDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _privacyCaption(String privacy) {
    return 'Visibility: ${privacy.toUpperCase()}';
  }

  String _safeShortId(String id) {
    if (id.length <= 6) return id;
    return id.substring(0, 6);
  }
}

class _DemoSongPostCard extends StatelessWidget {
  const _DemoSongPostCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardColor = isLight ? Colors.white : const Color(0xFF1E232D);
    final borderColor = isLight ? const Color(0xFFE5E7EB) : const Color(0xFF2D3442);
    final titleTextColor = isLight ? const Color(0xFF111827) : Colors.white;
    final mutedTextColor = isLight ? const Color(0xFF6B7280) : const Color(0xFFB8C0D0);
    final bodyTextColor = isLight ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE5E7EB),
                child: Icon(Icons.person, size: 16, color: Color(0xFF111827)),
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
                  color: const Color(0xFFE5EDFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'DEMO',
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF1E40AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Now playing: Midnight City - M83',
            style: textTheme.bodyMedium?.copyWith(
              color: bodyTextColor,
            ),
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
