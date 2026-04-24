import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_posts_list.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/core/widgets/tab_accent_strip.dart';
import 'package:image_picker/image_picker.dart';

enum _TopFiveCategory { tracks, albums, artists }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.viewModel, this.userId});

  final ProfileViewModel viewModel;
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  _TopFiveCategory _topFiveCategory = _TopFiveCategory.tracks;
  bool _spotifyConnected = true;
  String? _syncedProfileId;

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
        final title = _resolveTitle(l10n, state);
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: scheme.onSurface,
            surfaceTintColor: Colors.transparent,
            leading: const AppTopNavLeading(),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface,
                  scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                  scheme.primary.withValues(alpha: 0.10),
                ],
              ),
            ),
            child: RefreshIndicator(
              onRefresh: () async => _loadProfile(),
              child: Column(
                children: [
                  const TabAccentStrip(tab: AppBottomNavTab.profile),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderSection(context, l10n, state),
                          const SizedBox(height: 14),
                          _buildPostsSection(context, l10n, state),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const AppBottomNavBar(
            currentTab: AppBottomNavTab.profile,
          ),
        );
      },
    );
  }

  String _resolveTitle(AppLocalizations l10n, ProfileViewState state) {
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
        return const _ProfilePanel(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      case HeaderLoadState.data:
        return _ProfilePanel(
          child: _buildProfileOverview(context, state.header!, state),
        );
      case HeaderLoadState.empty:
        return _ProfilePanel(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.profileEmptyBioMessage),
          ),
        );
      case HeaderLoadState.error:
        return _ProfilePanel(
          child: Padding(
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
          ),
        );
      case HeaderLoadState.notFound:
        return _ProfilePanel(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.profileNotFoundMessage),
          ),
        );
      case HeaderLoadState.authRequired:
        return _ProfilePanel(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.profileLoadErrorMessage),
          ),
        );
    }
  }

  Widget _buildPostsSection(
    BuildContext context,
    AppLocalizations l10n,
    ProfileViewState state,
  ) {
    return _ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.profilePostsSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${state.totalPostsCount} posts',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPostsContent(l10n, state),
        ],
      ),
    );
  }

  Widget _buildProfileOverview(
    BuildContext context,
    ProfileHeader header,
    ProfileViewState state,
  ) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final primaryText = theme.colorScheme.onSurface;
    final secondaryText = theme.colorScheme.onSurfaceVariant;

    final editable = _parseEditableProfileData(
      header,
      fallbackSpotifyConnected: _spotifyConnected,
    );
    if (_syncedProfileId != header.id) {
      _syncedProfileId = header.id;
      _spotifyConnected = editable.spotifyConnected;
    }

    final topFiveItems = _topItems(header, state, _topFiveCategory);
    final universityName = editable.universityName;
    final classYear = editable.graduationYear;
    final studyYear = editable.studyYear?.label;
    final friendCount = header.followersCount;
    final postsCount = state.totalPostsCount;
    final avatarProvider = _profileImageProvider(
      header: header,
      localAvatarPath: state.localAvatarPath,
    );
    final heroGradient = isLight
        ? const [Color(0xFF3058FF), Color(0xFF7A42FF)]
        : const [Color(0xFF21336E), Color(0xFF462966)];
    final relationSummary = [
      if (editable.gender != _GenderOption.preferNotToSay)
        editable.gender.label,
      if (editable.age != null) '${editable.age} yrs',
    ].join(' | ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: heroGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: heroGradient.first.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Music Identity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(
                    radius: 35,
                    backgroundColor: Colors.white.withValues(alpha: 0.26),
                    imageProvider: avatarProvider,
                    fallbackText: header.username.isNotEmpty
                        ? header.username[0].toUpperCase()
                        : '?',
                    fallbackTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editable.fullName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${editable.username}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                editable.bio.trim().isEmpty
                    ? 'Music lover and student in Budapest.'
                    : editable.bio,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.90),
                  height: 1.35,
                ),
              ),
              if (relationSummary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    relationSummary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProfileStatChip(
                    label: 'Friends',
                    value: friendCount,
                    icon: Icons.group_rounded,
                  ),
                  _ProfileStatChip(
                    label: 'Posts',
                    value: postsCount,
                    icon: Icons.auto_stories_rounded,
                  ),
                  _ProfileStatChip(
                    label: 'Following',
                    value: header.followingCount,
                    icon: Icons.person_add_rounded,
                  ),
                  _ProfileStatChip(
                    label: 'Genres',
                    value: header.preferredGenres.length,
                    icon: Icons.graphic_eq_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (widget.userId == null)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showEditProfileSheet(state),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit profile'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: FilledButton.icon(
                  onPressed: _canRunFollowAction(state) ? _followUser : null,
                  icon: state.isFollowActionInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_followActionIcon(state)),
                  label: Text(_followActionLabel(state)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.userId == null
                    ? _pickProfilePhoto
                    : () => context.push(
                        '${Routes.messages}/${Uri.encodeComponent(widget.userId!)}',
                      ),
                icon: Icon(
                  widget.userId == null
                      ? Icons.photo_camera_outlined
                      : Icons.person_add_alt_1_rounded,
                ),
                label: Text(
                  widget.userId == null ? 'Change photo' : 'Add friend',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (header.preferredGenres.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Favorite genres',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: header.preferredGenres
                      .take(8)
                      .map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            genre,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A3FFF), Color(0xFF7C4DFF)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        universityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        studyYear == null
                            ? 'Class of $classYear'
                            : '$studyYear • Class of $classYear',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.userId == null)
                  TextButton.icon(
                    onPressed: () => _editUniversityYear(state, classYear),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Top 5',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 140,
                        maxWidth: 190,
                      ),
                      child: DropdownButtonFormField<_TopFiveCategory>(
                        initialValue: _topFiveCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        selectedItemBuilder: (context) => _TopFiveCategory
                            .values
                            .map(
                              (category) => Row(
                                children: [
                                  Icon(
                                    _topFiveCategoryIcon(category),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _topFiveCategoryLabel(category),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(growable: false),
                        items: _TopFiveCategory.values
                            .map(
                              (category) => DropdownMenuItem<_TopFiveCategory>(
                                value: category,
                                child: Row(
                                  children: [
                                    Icon(
                                      _topFiveCategoryIcon(category),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_topFiveCategoryLabel(category)),
                                  ],
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _topFiveCategory = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: topFiveItems
                    .asMap()
                    .entries
                    .map(
                      (entry) => _TopFiveListItem(
                        item: entry.value,
                        rank: entry.key + 1,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Spotify Connected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                value: _spotifyConnected,
                onChanged: (enabled) {
                  setState(() {
                    _spotifyConnected = enabled;
                  });
                },
              ),
              if (_spotifyConnected)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connected and syncing',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Spotify refreshed.'),
                                ),
                              );
                            },
                            child: const Text('Refresh'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _spotifyConnected = false;
                              });
                            },
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
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
          onViewComments: widget.viewModel.loadPostComments,
          onAddComment: widget.viewModel.addPostComment,
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
          onViewComments: widget.viewModel.loadPostComments,
          onAddComment: widget.viewModel.addPostComment,
        );
    }
  }

  Future<void> _showEditProfileSheet(ProfileViewState state) async {
    if (widget.userId != null || state.header == null) return;
    final initial = _parseEditableProfileData(
      state.header!,
      fallbackSpotifyConnected: _spotifyConnected,
    );
    final fullNameController = TextEditingController(text: initial.fullName);
    final usernameController = TextEditingController(text: initial.username);
    final ageController = TextEditingController(
      text: initial.age?.toString() ?? '',
    );
    final bioController = TextEditingController(text: initial.bio);
    final universityController = TextEditingController(
      text: initial.universityName,
    );
    String selectedUniversity =
        _universityOptions.contains(initial.universityName)
        ? initial.universityName
        : _otherUniversityOption;
    var selectedGender = initial.gender;
    var selectedYear = initial.graduationYear;
    var selectedStudyYear = initial.studyYear;
    var spotifyConnected = initial.spotifyConnected;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Profile',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _editorSectionTitle('Personal Information'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<_GenderOption>(
                      initialValue: selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: _GenderOption.values
                          .map(
                            (gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(gender.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => selectedGender = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bioController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 14),
                    _editorSectionTitle('Education'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUniversity,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'University Name',
                      ),
                      items: _universityOptions
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      selectedItemBuilder: (context) => _universityOptions
                          .map(
                            (name) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => selectedUniversity = value);
                      },
                    ),
                    if (selectedUniversity == _otherUniversityOption) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: universityController,
                        decoration: const InputDecoration(
                          labelText: 'Custom University Name',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Graduation Year',
                      ),
                      items: [
                        for (var y = 2024; y <= 2030; y++)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => selectedYear = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<_StudyYearOption>(
                      initialValue: selectedStudyYear,
                      decoration: const InputDecoration(
                        labelText: 'Year of Study',
                      ),
                      items: _StudyYearOption.values
                          .map(
                            (year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setModalState(() => selectedStudyYear = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    _editorSectionTitle('Music'),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Spotify Connected'),
                      subtitle: Text(spotifyConnected ? 'Active' : 'Inactive'),
                      value: spotifyConnected,
                      onChanged: (value) {
                        setModalState(() => spotifyConnected = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            child: const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) {
      fullNameController.dispose();
      usernameController.dispose();
      ageController.dispose();
      bioController.dispose();
      universityController.dispose();
      return;
    }

    try {
      final age = int.tryParse(ageController.text.trim());
      final data = _EditableProfileData(
        fullName: fullNameController.text.trim().isEmpty
            ? initial.fullName
            : fullNameController.text.trim(),
        username: usernameController.text.trim().isEmpty
            ? initial.username
            : usernameController.text.trim(),
        gender: selectedGender,
        age: age,
        bio: bioController.text.trim(),
        universityName: selectedUniversity == _otherUniversityOption
            ? (universityController.text.trim().isEmpty
                  ? initial.universityName
                  : universityController.text.trim())
            : selectedUniversity,
        graduationYear: selectedYear,
        studyYear: selectedStudyYear,
        spotifyConnected: spotifyConnected,
      );
      await widget.viewModel.saveBio(_buildBioFromEditableProfileData(data));
      if (!mounted) return;
      setState(() => _spotifyConnected = spotifyConnected);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile.')),
      );
    } finally {
      fullNameController.dispose();
      usernameController.dispose();
      ageController.dispose();
      bioController.dispose();
      universityController.dispose();
    }
  }

  Future<void> _editUniversityYear(
    ProfileViewState state,
    int currentYear,
  ) async {
    if (widget.userId != null || state.header == null) return;
    final now = DateTime.now().year;
    var selectedYear = currentYear.clamp(now - 1, now + 8);
    final year = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select graduation year',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    items: [
                      for (var y = now - 1; y <= now + 8; y++)
                        DropdownMenuItem(value: y, child: Text('Class of $y')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => selectedYear = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selectedYear),
                      child: const Text('Save year'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (year == null) return;

    try {
      final base = _parseEditableProfileData(
        state.header!,
        fallbackSpotifyConnected: _spotifyConnected,
      );
      final next = base.copyWith(graduationYear: year);
      await widget.viewModel.saveBio(_buildBioFromEditableProfileData(next));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('University year updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update university year.')),
      );
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

  Widget _editorSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.90)
            : const Color(0xE81E232D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight ? const Color(0xFFDDE4F5) : const Color(0xFF323C52),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: isLight ? 0.06 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF6F8FF) : const Color(0xFF171D29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight ? const Color(0xFFD7DEEE) : const Color(0xFF2E3647),
        ),
      ),
      child: child,
    );
  }
}

class _ProfileStatChip extends StatelessWidget {
  const _ProfileStatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFiveItem {
  const _TopFiveItem({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String seed;
  final IconData icon;
}

String _topFiveCategoryLabel(_TopFiveCategory category) {
  switch (category) {
    case _TopFiveCategory.tracks:
      return 'Tracks';
    case _TopFiveCategory.albums:
      return 'Albums';
    case _TopFiveCategory.artists:
      return 'Artists';
  }
}

IconData _topFiveCategoryIcon(_TopFiveCategory category) {
  switch (category) {
    case _TopFiveCategory.tracks:
      return Icons.music_note_rounded;
    case _TopFiveCategory.albums:
      return Icons.album_rounded;
    case _TopFiveCategory.artists:
      return Icons.person_rounded;
  }
}

class _TopFiveListItem extends StatelessWidget {
  const _TopFiveListItem({required this.item, required this.rank});

  final _TopFiveItem item;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = _seedGradient(item.seed);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF1D2431),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F3) : const Color(0xFF2B3445),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: colors),
            ),
            child: Icon(item.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

ImageProvider<Object>? _profileImageProvider({
  required ProfileHeader header,
  required String? localAvatarPath,
}) {
  final local = localAvatarPath;
  if (local != null && local.isNotEmpty) {
    return FileImage(File(local));
  }
  final url = header.avatarUrl;
  if (url != null && url.isNotEmpty) {
    return NetworkImage(url);
  }
  return null;
}

String _displayNameFromUsername(String username) {
  final cleaned = username.replaceAll(RegExp(r'[_\.]+'), ' ').trim();
  if (cleaned.isEmpty) return username;
  return cleaned
      .split(' ')
      .where((s) => s.isNotEmpty)
      .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}

List<_TopFiveItem> _topItems(
  ProfileHeader header,
  ProfileViewState state,
  _TopFiveCategory category,
) {
  final tracks = <_TopFiveItem>[];
  for (final post in state.posts) {
    for (final attachment in post.attachments) {
      if (attachment.type != 'spotify_link') continue;
      final url = attachment.url ?? '';
      if (url.trim().isEmpty) continue;
      final uri = Uri.tryParse(url);
      final host = uri?.host.isNotEmpty == true ? uri!.host : 'Spotify link';
      final segment = (uri?.pathSegments.isNotEmpty == true)
          ? uri!.pathSegments.last
          : 'Track';
      tracks.add(
        _TopFiveItem(
          title:
              'Track ${segment.length > 10 ? segment.substring(0, 10) : segment}',
          subtitle: host,
          seed: url,
          icon: Icons.music_note_rounded,
        ),
      );
    }
  }

  if (tracks.isEmpty) {
    final fallbackGenres = header.preferredGenres.isEmpty
        ? const ['House', 'Afrobeats', 'Lo-Fi', 'Pop', 'Indie']
        : header.preferredGenres.take(5).toList(growable: false);
    for (final genre in fallbackGenres) {
      tracks.add(
        _TopFiveItem(
          title: '$genre Session',
          subtitle: 'Student playlist',
          seed: genre,
          icon: Icons.music_note_rounded,
        ),
      );
    }
  }

  final baseGenres = header.preferredGenres.isEmpty
      ? const ['Electronic', 'Hip-Hop', 'Indie', 'Pop', 'Jazz']
      : header.preferredGenres;
  final albums = baseGenres
      .take(5)
      .map((genre) {
        return _TopFiveItem(
          title: '$genre Essentials',
          subtitle: 'Top album mix',
          seed: 'album-$genre',
          icon: Icons.album_rounded,
        );
      })
      .toList(growable: false);
  final artists = baseGenres
      .take(5)
      .map((genre) {
        return _TopFiveItem(
          title: '$genre Collective',
          subtitle: 'Artist spotlight',
          seed: 'artist-$genre',
          icon: Icons.person_rounded,
        );
      })
      .toList(growable: false);

  switch (category) {
    case _TopFiveCategory.tracks:
      return tracks.take(5).toList(growable: false);
    case _TopFiveCategory.albums:
      return albums;
    case _TopFiveCategory.artists:
      return artists;
  }
}

List<Color> _seedGradient(String seed) {
  final hash = seed.hashCode;
  final first = Color.fromARGB(
    255,
    80 + ((hash >> 4) & 0x6F),
    70 + ((hash >> 2) & 0x5F),
    110 + ((hash >> 5) & 0x6F),
  );
  final second = Color.fromARGB(
    255,
    70 + ((hash >> 7) & 0x5F),
    80 + ((hash >> 3) & 0x6F),
    120 + ((hash >> 1) & 0x6F),
  );
  return [first, second];
}

String _bioWithoutClassYear(String? bio) {
  if (bio == null || bio.trim().isEmpty) return '';
  final lines = bio
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !_classYearRegex.hasMatch(line))
      .toList(growable: false);
  return lines.join('\n');
}

final RegExp _classYearRegex = RegExp(
  r'\bclass of\s*(20\d{2})\b',
  caseSensitive: false,
);

enum _GenderOption {
  male('Male'),
  female('Female'),
  nonBinary('Non-binary'),
  preferNotToSay('Prefer not to say');

  const _GenderOption(this.label);
  final String label;

  static _GenderOption fromValue(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'male':
        return _GenderOption.male;
      case 'female':
        return _GenderOption.female;
      case 'non-binary':
      case 'non binary':
      case 'nonbinary':
        return _GenderOption.nonBinary;
      default:
        return _GenderOption.preferNotToSay;
    }
  }
}

enum _StudyYearOption {
  first('1st Year'),
  second('2nd Year'),
  third('3rd Year');

  const _StudyYearOption(this.label);
  final String label;

  static _StudyYearOption? fromValue(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case '1st year':
      case 'first year':
        return _StudyYearOption.first;
      case '2nd year':
      case 'second year':
        return _StudyYearOption.second;
      case '3rd year':
      case 'third year':
        return _StudyYearOption.third;
      default:
        return null;
    }
  }
}

class _EditableProfileData {
  const _EditableProfileData({
    required this.fullName,
    required this.username,
    required this.gender,
    required this.age,
    required this.bio,
    required this.universityName,
    required this.graduationYear,
    required this.studyYear,
    required this.spotifyConnected,
  });

  final String fullName;
  final String username;
  final _GenderOption gender;
  final int? age;
  final String bio;
  final String universityName;
  final int graduationYear;
  final _StudyYearOption? studyYear;
  final bool spotifyConnected;

  _EditableProfileData copyWith({
    String? fullName,
    String? username,
    _GenderOption? gender,
    int? age,
    bool clearAge = false,
    String? bio,
    String? universityName,
    int? graduationYear,
    _StudyYearOption? studyYear,
    bool? spotifyConnected,
  }) {
    return _EditableProfileData(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      gender: gender ?? this.gender,
      age: clearAge ? null : (age ?? this.age),
      bio: bio ?? this.bio,
      universityName: universityName ?? this.universityName,
      graduationYear: graduationYear ?? this.graduationYear,
      studyYear: studyYear ?? this.studyYear,
      spotifyConnected: spotifyConnected ?? this.spotifyConnected,
    );
  }
}

_EditableProfileData _parseEditableProfileData(
  ProfileHeader header, {
  required bool fallbackSpotifyConnected,
}) {
  final meta = _extractMetaMap(header.bio);
  final bio = _stripMetaBlock(header.bio);
  final inferredUniversity = _inferUniversityFromBio(bio);
  final inferredYear = _inferClassYearFromBio(header, bio);
  final age = int.tryParse(_metaValue(meta, 'age', 'a') ?? '');
  final graduationYear =
      int.tryParse(_metaValue(meta, 'graduation_year', 'gy') ?? '') ??
      inferredYear;
  return _EditableProfileData(
    fullName: (_metaValue(meta, 'full_name', 'fn')?.trim().isNotEmpty == true)
        ? _metaValue(meta, 'full_name', 'fn')!.trim()
        : _displayNameFromUsername(header.username),
    username: (_metaValue(meta, 'username', 'un')?.trim().isNotEmpty == true)
        ? _metaValue(meta, 'username', 'un')!.trim()
        : header.username,
    gender: _GenderOption.fromValue(_metaValue(meta, 'gender', 'g')),
    age: age,
    bio: bio,
    universityName:
        (_metaValue(meta, 'university_name', 'u')?.trim().isNotEmpty == true)
        ? _metaValue(meta, 'university_name', 'u')!.trim()
        : inferredUniversity,
    graduationYear: graduationYear,
    studyYear: _StudyYearOption.fromValue(_metaValue(meta, 'study_year', 'sy')),
    spotifyConnected:
        (_metaValue(meta, 'spotify_connected', 'sp')?.trim().toLowerCase() ==
            'true')
        ? true
        : (meta.containsKey('spotify_connected') || meta.containsKey('sp')
              ? false
              : fallbackSpotifyConnected),
  );
}

String _buildBioFromEditableProfileData(_EditableProfileData data) {
  final bio = data.bio.trim();
  final fullLines = <String>[
    'full_name=${data.fullName.trim()}',
    'username=${data.username.trim()}',
    'gender=${data.gender.label}',
    if (data.age != null) 'age=${data.age}',
    'university_name=${data.universityName.trim()}',
    'graduation_year=${data.graduationYear}',
    if (data.studyYear != null) 'study_year=${data.studyYear!.label}',
    'spotify_connected=${data.spotifyConnected}',
  ];
  final full = _composeMetaBio(baseBio: bio, metaLines: fullLines);
  if (full.length <= _profileBioMaxLength) return full;

  final compactLines = <String>[
    'fn=${data.fullName.trim()}',
    'un=${data.username.trim()}',
    'g=${data.gender.label}',
    if (data.age != null) 'a=${data.age}',
    'u=${data.universityName.trim()}',
    'gy=${data.graduationYear}',
    if (data.studyYear != null) 'sy=${data.studyYear!.label}',
    'sp=${data.spotifyConnected}',
  ];
  final compact = _composeMetaBio(baseBio: bio, metaLines: compactLines);
  if (compact.length <= _profileBioMaxLength) return compact;

  final minimalLines = <String>[
    'u=${data.universityName.trim()}',
    'gy=${data.graduationYear}',
    if (data.studyYear != null) 'sy=${data.studyYear!.label}',
  ];
  final minimal = _composeMetaBio(baseBio: bio, metaLines: minimalLines);
  if (minimal.length <= _profileBioMaxLength) return minimal;

  return _buildLengthSafeClassYearBio(
    baseBio: bio,
    year: data.graduationYear,
    studyYear: data.studyYear,
  );
}

String _composeMetaBio({
  required String baseBio,
  required List<String> metaLines,
}) {
  final lines = <String>[];
  if (baseBio.isNotEmpty) lines.add(baseBio);
  lines.add(_metaStartTag);
  lines.addAll(metaLines);
  lines.add(_metaEndTag);
  return lines.join('\n');
}

String? _metaValue(Map<String, String> meta, String longKey, String shortKey) {
  return meta[longKey] ?? meta[shortKey];
}

String _buildLengthSafeClassYearBio({
  required String baseBio,
  required int year,
  _StudyYearOption? studyYear,
}) {
  final suffixLines = <String>[
    if (studyYear != null) studyYear.label,
    'Class of $year',
  ];
  final suffix = suffixLines.join('\n');
  if (baseBio.isEmpty) {
    return suffix.length <= _profileBioMaxLength ? suffix : 'Class of $year';
  }
  final maxBaseLength = _profileBioMaxLength - suffix.length - 1;
  if (maxBaseLength <= 0) return 'Class of $year';
  final normalizedBase = baseBio.length > maxBaseLength
      ? '${baseBio.substring(0, maxBaseLength - 1).trimRight()}…'
      : baseBio;
  return '$normalizedBase\n$suffix';
}

Map<String, String> _extractMetaMap(String? sourceBio) {
  final bio = sourceBio ?? '';
  final match = _metaBlockRegex.firstMatch(bio);
  if (match == null) return const {};
  final block = match.group(1) ?? '';
  final map = <String, String>{};
  for (final line in block.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final sep = trimmed.indexOf('=');
    if (sep <= 0) continue;
    final key = trimmed.substring(0, sep).trim().toLowerCase();
    final value = trimmed.substring(sep + 1).trim();
    if (key.isEmpty) continue;
    map[key] = value;
  }
  return map;
}

String _stripMetaBlock(String? sourceBio) {
  final bio = sourceBio ?? '';
  final stripped = bio.replaceAll(_metaBlockRegex, '').trim();
  return _bioWithoutClassYear(stripped);
}

String _inferUniversityFromBio(String bio) {
  final normalized = bio.toLowerCase();
  if (normalized.contains('elte')) return 'Eotvos Lorand University';
  if (normalized.contains('bme')) {
    return 'Budapest University of Technology and Economics';
  }
  if (normalized.contains('corvinus')) return 'Corvinus University of Budapest';
  return 'International Business School Budapest';
}

int _inferClassYearFromBio(ProfileHeader header, String bio) {
  final classMatch = _classYearRegex.firstMatch(bio);
  if (classMatch != null) {
    return int.tryParse(classMatch.group(1) ?? '') ?? 2027;
  }
  final years = RegExp(r'(20[2-4][0-9])').allMatches(bio);
  if (years.isNotEmpty) {
    return int.tryParse(years.first.group(0) ?? '') ?? 2027;
  }
  final estimated = header.createdAt.year + 4;
  if (estimated < 2024 || estimated > 2030) return 2027;
  return estimated;
}

const String _metaStartTag = '[echo_meta]';
const String _metaEndTag = '[/echo_meta]';
const int _profileBioMaxLength = 200;
const String _otherUniversityOption = 'Other';
const List<String> _universityOptions = [
  'International Business School Budapest',
  'Eotvos Lorand University',
  'Budapest University of Technology and Economics',
  'Corvinus University of Budapest',
  'Semmelweis University',
  'Budapest Metropolitan University',
  'Obuda University',
  'University of Public Service',
  'Moholy-Nagy University of Art and Design',
  'Central European University',
  _otherUniversityOption,
];
final RegExp _metaBlockRegex = RegExp(
  r'\[echo_meta\]([\s\S]*?)\[/echo_meta\]',
  caseSensitive: false,
);
