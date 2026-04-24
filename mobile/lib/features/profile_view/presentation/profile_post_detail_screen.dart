import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';

class ProfilePostDetailScreen extends StatefulWidget {
  const ProfilePostDetailScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.loadComments,
    required this.addComment,
  });

  final List<ProfilePostSummary> posts;
  final int initialIndex;
  final Future<List<ProfilePostComment>> Function(String postId) loadComments;
  final Future<ProfilePostComment?> Function(String postId, String content)
  addComment;

  @override
  State<ProfilePostDetailScreen> createState() =>
      _ProfilePostDetailScreenState();
}

class _ProfilePostDetailScreenState extends State<ProfilePostDetailScreen> {
  late final PageController _pageController;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _loadingComments = <String>{};
  final Map<String, List<ProfilePostComment>> _commentsByPostId =
      <String, List<ProfilePostComment>>{};
  int _currentIndex = 0;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.posts.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadCommentsForCurrent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  ProfilePostSummary get _currentPost => widget.posts[_currentIndex];

  Future<void> _loadCommentsForCurrent() async {
    await _loadCommentsForPost(_currentPost.id);
  }

  Future<void> _loadCommentsForPost(String postId) async {
    if (_loadingComments.contains(postId)) return;
    setState(() => _loadingComments.add(postId));
    try {
      final items = await widget.loadComments(postId);
      if (!mounted) return;
      setState(() {
        _commentsByPostId[postId] = items;
      });
    } catch (_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not load comments right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingComments.remove(postId));
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final created = await widget.addComment(_currentPost.id, text);
      if (!mounted) return;
      if (created != null) {
        final existing = _commentsByPostId[_currentPost.id] ?? const [];
        _commentsByPostId[_currentPost.id] = [...existing, created];
        _commentController.clear();
      }
    } catch (_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send comment. Please retry.')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _currentPost;
    final comments = _commentsByPostId[post.id] ?? const <ProfilePostComment>[];
    final loadingComments = _loadingComments.contains(post.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.80),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadCommentsForCurrent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.13),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                child: Text(
                                  _safeShortId(post.userId)[0].toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'User ${_safeShortId(post.userId)}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${_currentIndex + 1}/${widget.posts.length}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AspectRatio(
                            aspectRatio: 1,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: widget.posts.length,
                              onPageChanged: (index) {
                                setState(() => _currentIndex = index);
                                _loadCommentsForCurrent();
                              },
                              itemBuilder: (context, index) => _buildMediaBlock(
                                context,
                                widget.posts[index],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {},
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Like',
                                icon: const Icon(Icons.favorite_border_rounded),
                              ),
                              IconButton(
                                onPressed: () {},
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Comment',
                                icon: const Icon(Icons.mode_comment_outlined),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.send_rounded),
                                onPressed: () {},
                              ),
                              const Spacer(),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.bookmark_border_rounded),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          _buildCaption(context, post),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _buildCommentsPreview(
                              context,
                              comments,
                              loadingComments,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _humanDate(post.createdAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _sendingComment ? null : _sendComment,
                    icon: _sendingComment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaption(BuildContext context, ProfilePostSummary post) {
    final textAttachment = _firstTextAttachment(post.attachments);
    if (textAttachment == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'User ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: textAttachment.content?.trim() ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaBlock(BuildContext context, ProfilePostSummary post) {
    final scheme = Theme.of(context).colorScheme;
    final textAttachment = _firstTextAttachment(post.attachments);
    final mediaAttachment = _firstMediaAttachment(post.attachments);
    final spotifyAttachment = _firstSpotifyAttachment(post.attachments);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mediaAttachment?.url != null &&
              mediaAttachment!.url!.trim().isNotEmpty)
            Image.network(
              mediaAttachment.url!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _fallbackMedia(context, textAttachment),
            )
          else if (spotifyAttachment != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.92),
                    scheme.tertiary.withValues(alpha: 0.86),
                  ],
                ),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Spotify',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _fallbackMedia(context, textAttachment),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _privacyCaption(post.privacy),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackMedia(
    BuildContext context,
    PostAttachmentSummary? textAttachment,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
                size: 44,
              ),
              const SizedBox(height: 10),
              Text(
                textAttachment?.content?.trim().isNotEmpty == true
                    ? textAttachment!.content!
                    : 'Your post',
                maxLines: 4,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsPreview(
    BuildContext context,
    List<ProfilePostComment> comments,
    bool loading,
  ) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (comments.isEmpty) {
      return Text(
        'No comments yet.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final preview = comments.take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: preview
          .map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${comment.username} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: comment.content),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
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

  PostAttachmentSummary? _firstMediaAttachment(
    List<PostAttachmentSummary> attachments,
  ) {
    for (final attachment in attachments) {
      final url = attachment.url?.trim();
      if (url == null || url.isEmpty) continue;
      if (attachment.type == 'spotify_link') continue;
      return attachment;
    }
    return null;
  }
}
