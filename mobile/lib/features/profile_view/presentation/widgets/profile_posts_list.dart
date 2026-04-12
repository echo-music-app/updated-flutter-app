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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.profileEmptyPostsMessage),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return ListTile(
                key: ValueKey(post.id),
                title: Text(post.privacy),
                subtitle: Text(post.createdAt.toIso8601String()),
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
}
