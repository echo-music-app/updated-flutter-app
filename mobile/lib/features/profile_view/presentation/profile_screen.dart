import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_header.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_posts_list.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.viewModel, this.userId});

  final ProfileViewModel viewModel;
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(context, l10n, state),
                const Divider(),
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
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      case HeaderLoadState.data:
        return ProfileHeaderWidget(header: state.header!);
      case HeaderLoadState.empty:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.profileEmptyBioMessage),
        );
      case HeaderLoadState.error:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
          padding: const EdgeInsets.all(16),
          child: Text(l10n.profileNotFoundMessage),
        );
      case HeaderLoadState.authRequired:
        return Padding(
          padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profilePostsSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
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
        return Text(l10n.profileEmptyPostsMessage);
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
}
