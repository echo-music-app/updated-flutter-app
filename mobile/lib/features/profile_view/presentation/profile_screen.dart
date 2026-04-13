import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_header.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_posts_list.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';
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
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Open menu',
              onPressed: () => showAppSidebar(context),
            ),
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
        return ProfileHeaderWidget(
          header: state.header!,
          localAvatarPath: state.localAvatarPath,
          canEdit: widget.userId == null,
          onEditBio: () => _showEditBioDialog(state),
          onEditPhoto: _pickProfilePhoto,
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
        const SnackBar(content: Text('Could not update bio. Please try again.')),
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
}
