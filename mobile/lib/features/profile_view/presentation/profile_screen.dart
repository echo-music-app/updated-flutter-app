import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_header.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_posts_list.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.viewModel, this.userId});

  final ProfileViewModel viewModel;
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.viewModel != widget.viewModel) {
      _loadProfile();
    }
  }

  void _loadProfile() {
    widget.viewModel.loadProfile(userId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final isOwn =
            state.header != null ||
            state.headerState == HeaderLoadState.loading;
        final title = _resolveTitle(l10n, state, isOwn);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            leading: const AppTopNavLeading(),
            title: Text(title),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(context, l10n, state),
                const SizedBox(height: 16),
                _buildPostsSection(context, l10n, state),
              ],
            ),
          ),
          bottomNavigationBar: const AppBottomNavBar(
            currentTab: AppBottomNavTab.profile,
          ),
        );
      },
    );
  }

  String _resolveTitle(
    AppLocalizations l10n,
    ProfileViewState state,
    bool isOwn,
  ) {
    if (widget.userId == null) return l10n.myProfileTitle;
    if (state.header != null) {
      if (widget.userId == null) return l10n.myProfileTitle;
      return l10n.userProfileTitle(state.header!.username);
    }
    return l10n.profileTitle;
  }

  Widget _buildHeaderSection(
    BuildContext context,
    AppLocalizations l10n,
    ProfileViewState state,
  ) {
    switch (state.headerState) {
      case HeaderLoadState.loading:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      case HeaderLoadState.data:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeaderWidget(
              header: state.header!,
              postsCount: state.totalPostsCount,
              localAvatarPath: state.localAvatarPath,
              canEdit: widget.userId == null,
              onEditBio: () => _showEditBioDialog(state),
              onEditPhoto: _pickProfilePhoto,
              onTapFollowers: widget.userId == null
                  ? () => context.push(Routes.friendsFollowers)
                  : null,
              onTapFollowing: widget.userId == null
                  ? () => context.push(Routes.friendsFollowing)
                  : null,
            ),
            if (widget.userId != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _canRunFollowAction(state) ? _followUser : null,
                icon: state.isFollowActionInProgress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_followActionIcon(state)),
                label: Text(_followActionLabel(state)),
              ),
              if (state.followRelationStatus == FollowRelationStatus.accepted)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '${Routes.messages}/${Uri.encodeComponent(widget.userId!)}',
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Message'),
                  ),
                ),
            ],
          ],
        );
      case HeaderLoadState.empty:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(l10n.profileEmptyBioMessage),
        );
      case HeaderLoadState.error:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.profileLoadErrorMessage),
              const SizedBox(height: 8),
              Semantics(
                label: l10n.retryButton,
                child: ElevatedButton(
                  onPressed: widget.viewModel.retryHeader,
                  child: Text(l10n.retryButton),
                ),
              ),
            ],
          ),
        );
      case HeaderLoadState.notFound:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(l10n.profileNotFoundMessage),
        );
      case HeaderLoadState.authRequired:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(l10n.profileLoadErrorMessage),
        );
    }
  }

  Widget _buildPostsSection(
    BuildContext context,
    AppLocalizations l10n,
    ProfileViewState state,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profilePostsSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildPostsContent(l10n, state),
        ],
      ),
    );
  }

  Widget _buildPostsContent(AppLocalizations l10n, ProfileViewState state) {
    switch (state.postsState) {
      case PostsLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case PostsLoadState.empty:
        return ProfilePostsList(
          posts: const [],
          canLoadMore: false,
          isLoadingMore: false,
          onLoadMore: widget.viewModel.loadMore,
          onRetryLoadMore: widget.viewModel.retryPosts,
        );
      case PostsLoadState.error:
        return Column(
          children: [
            Text(l10n.profilePostsLoadErrorMessage),
            const SizedBox(height: 8),
            Semantics(
              label: l10n.retryButton,
              child: ElevatedButton(
                onPressed: widget.viewModel.retryPosts,
                child: Text(l10n.retryButton),
              ),
            ),
          ],
        );
      case PostsLoadState.authRequired:
        return Text(l10n.profileLoadErrorMessage);
      case PostsLoadState.data:
        return ProfilePostsList(
          posts: state.posts,
          canLoadMore: state.canLoadMore,
          isLoadingMore: state.isLoadingMore,
          onLoadMore: widget.viewModel.loadMore,
          onRetryLoadMore: widget.viewModel.retryPosts,
        );
    }
  }

  Future<void> _showEditBioDialog(ProfileViewState state) async {
    if (widget.userId != null || state.header == null) return;
    final controller = TextEditingController(text: state.header?.bio ?? '');
    try {
      final newBio = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Bio'),
            content: TextField(
              controller: controller,
              maxLength: 200,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Write something about yourself',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (newBio == null) return;

      await widget.viewModel.saveBio(newBio);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bio updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update bio. Please try again.'),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (widget.userId != null) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return;
      await widget.viewModel.uploadAvatar(image.path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile picture. Please try again.'),
        ),
      );
    }
  }

  Future<void> _followUser() async {
    try {
      await widget.viewModel.performFollowAction();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Relationship updated.'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Feed',
            onPressed: () {
              messenger.hideCurrentSnackBar();
              context.go(Routes.home);
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not follow user. Please try again.'),
        ),
      );
    }
  }

  bool _canRunFollowAction(ProfileViewState state) {
    if (state.isFollowActionInProgress) return false;
    switch (state.followRelationStatus) {
      case FollowRelationStatus.none:
      case FollowRelationStatus.pendingIncoming:
        return true;
      case FollowRelationStatus.pendingOutgoing:
      case FollowRelationStatus.accepted:
      case FollowRelationStatus.self:
        return false;
    }
  }

  IconData _followActionIcon(ProfileViewState state) {
    switch (state.followRelationStatus) {
      case FollowRelationStatus.pendingIncoming:
        return Icons.check_rounded;
      case FollowRelationStatus.pendingOutgoing:
        return Icons.schedule_rounded;
      case FollowRelationStatus.accepted:
        return Icons.check_rounded;
      case FollowRelationStatus.self:
        return Icons.person_rounded;
      case FollowRelationStatus.none:
        return Icons.person_add_alt_1_rounded;
    }
  }

  String _followActionLabel(ProfileViewState state) {
    switch (state.followRelationStatus) {
      case FollowRelationStatus.pendingIncoming:
        return 'Accept Request';
      case FollowRelationStatus.pendingOutgoing:
        return 'Requested';
      case FollowRelationStatus.accepted:
        return 'Following';
      case FollowRelationStatus.self:
        return 'My Profile';
      case FollowRelationStatus.none:
        return 'Follow';
    }
  }
}
