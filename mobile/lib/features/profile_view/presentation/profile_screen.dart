import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_posts_list.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/login_style_controller.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/core/widgets/tab_accent_strip.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

const _kProfileTrendAccent = Color(0xFFFF6B4A);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.viewModel, this.userId});

  final ProfileViewModel viewModel;
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
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
        final activeStyle = context.watch<LoginStyleController>().style;
        final palette = _ProfilePalette.forStyle(activeStyle);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: palette.appBarColor,
            foregroundColor: palette.primaryText,
            surfaceTintColor: Colors.transparent,
            leading: const AppTopNavLeading(),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: palette.primaryText,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.backgroundGradient,
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
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        );
      case HeaderLoadState.data:
        return _buildProfileOverview(context, state.header!, state);
      case HeaderLoadState.empty:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.profileEmptyBioMessage),
        );
      case HeaderLoadState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.profileNotFoundMessage),
        );
      case HeaderLoadState.authRequired:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.profileLoadErrorMessage),
        );
    }
  }

  Widget _buildPostsSection(
    BuildContext context,
    AppLocalizations l10n,
    ProfileViewState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kProfileTrendAccent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.black),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'My Posts',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${state.totalPostsCount}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildPostsContent(l10n, state),
      ],
    );
  }

  Widget _buildProfileOverview(
    BuildContext context,
    ProfileHeader header,
    ProfileViewState state,
  ) {
    final theme = Theme.of(context);
    final editable = _parseEditableProfileData(
      header,
      fallbackSpotifyConnected: _spotifyConnected,
    );
    if (_syncedProfileId != header.id) {
      _syncedProfileId = header.id;
      _spotifyConnected = editable.spotifyConnected;
    }

    final postsCount = state.totalPostsCount;
    final followersCount = header.followersCount;
    final followingCount = header.followingCount;
    final avatarProvider = _profileImageProvider(
      header: header,
      localAvatarPath: state.localAvatarPath,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
            color: _kProfileTrendAccent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              AppAvatar(
                radius: 48,
                imageProvider: avatarProvider,
                backgroundColor: Colors.black.withValues(alpha: 0.10),
                fallbackText: header.username.isNotEmpty
                    ? header.username[0].toUpperCase()
                    : '?',
                fallbackTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                editable.fullName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${editable.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InstagramStat(value: postsCount, label: 'Posts'),
                  _InstagramStat(value: followersCount, label: 'Friends'),
                  _InstagramStat(value: followingCount, label: 'Following'),
                ],
              ),
            ],
          ),
        ),
        if (editable.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            editable.bio.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: widget.userId == null
                    ? () => _showEditProfileSheet(state)
                    : (_canRunFollowAction(state) ? _followUser : null),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(38),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: state.isFollowActionInProgress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.userId == null
                            ? 'Edit profile'
                            : _followActionLabel(state),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.userId == null
                    ? _pickProfilePhoto
                    : () => context.push(
                        '${Routes.messages}/${Uri.encodeComponent(widget.userId!)}',
                      ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(38),
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.userId == null ? 'Share profile' : 'Message',
                ),
              ),
            ),
          ],
        ),
        if (header.preferredGenres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: header.preferredGenres
                .take(6)
                .map((genre) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#$genre',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
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

class _ProfilePalette {
  const _ProfilePalette({
    required this.backgroundGradient,
    required this.appBarColor,
    required this.primaryText,
    required this.panelColor,
    required this.panelBorderColor,
    required this.panelShadowColor,
    required this.panelGlowColor,
    required this.sectionCardColor,
    required this.sectionCardBorderColor,
    required this.statChipColor,
    required this.statChipTextColor,
    required this.listItemCardColor,
    required this.listItemCardBorderColor,
    required this.variantChipColor,
    required this.variantChipBorderColor,
    required this.variantChipTextColor,
    required this.variantChipActiveColor,
    required this.variantChipActiveTextColor,
  });

  final List<Color> backgroundGradient;
  final Color appBarColor;
  final Color primaryText;
  final Color panelColor;
  final Color panelBorderColor;
  final Color panelShadowColor;
  final Color panelGlowColor;
  final Color sectionCardColor;
  final Color sectionCardBorderColor;
  final Color statChipColor;
  final Color statChipTextColor;
  final Color listItemCardColor;
  final Color listItemCardBorderColor;
  final Color variantChipColor;
  final Color variantChipBorderColor;
  final Color variantChipTextColor;
  final Color variantChipActiveColor;
  final Color variantChipActiveTextColor;

  static _ProfilePalette forStyle(LoginStyleVariant style) {
    switch (style) {
      case LoginStyleVariant.modernLight:
        return _ProfilePalette(
          backgroundGradient: const [
            Color(0xFFF2F3F8),
            Color(0xFFEFF1F7),
            Color(0xFFE8ECF6),
          ],
          appBarColor: const Color(0xFFF2F3F8),
          primaryText: const Color(0xFF111827),
          panelColor: Colors.white.withValues(alpha: 0.92),
          panelBorderColor: const Color(0xFFDDE4F5),
          panelShadowColor: const Color(0x1A000000),
          panelGlowColor: const Color(0x155F46FF),
          sectionCardColor: const Color(0xFFF6F8FF),
          sectionCardBorderColor: const Color(0xFFD7DEEE),
          statChipColor: const Color(0xFF5F46FF),
          statChipTextColor: Colors.white,
          listItemCardColor: Colors.white,
          listItemCardBorderColor: const Color(0xFFE2E8F3),
          variantChipColor: const Color(0xFFE8ECF5),
          variantChipBorderColor: const Color(0xFFD7DFEB),
          variantChipTextColor: const Color(0xFF546072),
          variantChipActiveColor: const Color(0xFF5F46FF),
          variantChipActiveTextColor: Colors.white,
        );
      case LoginStyleVariant.darkMode:
        return _ProfilePalette(
          backgroundGradient: const [
            Color(0xFF0E1230),
            Color(0xFF090D24),
            Color(0xFF131A3C),
          ],
          appBarColor: const Color(0xFF0E1230),
          primaryText: Colors.white,
          panelColor: const Color(0xE81E232D),
          panelBorderColor: const Color(0xFF323C52),
          panelShadowColor: const Color(0x3D000000),
          panelGlowColor: const Color(0x1F5F46FF),
          sectionCardColor: const Color(0xFF171D29),
          sectionCardBorderColor: const Color(0xFF2E3647),
          statChipColor: const Color(0xFF2D3A52),
          statChipTextColor: Colors.white,
          listItemCardColor: const Color(0xFF1D2431),
          listItemCardBorderColor: const Color(0xFF2B3445),
          variantChipColor: const Color(0xFF171E3A),
          variantChipBorderColor: const Color(0xFF2D3A52),
          variantChipTextColor: const Color(0xFFAFB9CC),
          variantChipActiveColor: const Color(0xFF5F46FF),
          variantChipActiveTextColor: Colors.white,
        );
      case LoginStyleVariant.gradientVibe:
        return _ProfilePalette(
          backgroundGradient: const [
            Color(0xFF6C4BFF),
            Color(0xFFF26A70),
            Color(0xFFFFB05A),
          ],
          appBarColor: const Color(0x336C4BFF),
          primaryText: Colors.white,
          panelColor: Colors.white.withValues(alpha: 0.14),
          panelBorderColor: Colors.white.withValues(alpha: 0.26),
          panelShadowColor: const Color(0x33000000),
          panelGlowColor: const Color(0x2BFFFFFF),
          sectionCardColor: Colors.white.withValues(alpha: 0.17),
          sectionCardBorderColor: Colors.white.withValues(alpha: 0.32),
          statChipColor: Colors.white.withValues(alpha: 0.20),
          statChipTextColor: Colors.white,
          listItemCardColor: Colors.white.withValues(alpha: 0.15),
          listItemCardBorderColor: Colors.white.withValues(alpha: 0.28),
          variantChipColor: Colors.white.withValues(alpha: 0.12),
          variantChipBorderColor: Colors.white.withValues(alpha: 0.24),
          variantChipTextColor: Colors.white70,
          variantChipActiveColor: Colors.white,
          variantChipActiveTextColor: const Color(0xFF6A4CFF),
        );
      case LoginStyleVariant.glassmorphism:
        return _ProfilePalette(
          backgroundGradient: const [
            Color(0xFFDCD4F5),
            Color(0xFFC8BEEB),
            Color(0xFFB3D5F0),
          ],
          appBarColor: const Color(0x40FFFFFF),
          primaryText: Colors.white,
          panelColor: Colors.white.withValues(alpha: 0.24),
          panelBorderColor: Colors.white.withValues(alpha: 0.40),
          panelShadowColor: const Color(0x26000000),
          panelGlowColor: const Color(0x196A4BFF),
          sectionCardColor: Colors.white.withValues(alpha: 0.30),
          sectionCardBorderColor: Colors.white.withValues(alpha: 0.46),
          statChipColor: const Color(0xFF6A4BFF),
          statChipTextColor: Colors.white,
          listItemCardColor: Colors.white.withValues(alpha: 0.32),
          listItemCardBorderColor: Colors.white.withValues(alpha: 0.48),
          variantChipColor: Colors.white.withValues(alpha: 0.24),
          variantChipBorderColor: Colors.white.withValues(alpha: 0.46),
          variantChipTextColor: const Color(0xFFEAF0FF),
          variantChipActiveColor: const Color(0xFF6A4BFF),
          variantChipActiveTextColor: Colors.white,
        );
      case LoginStyleVariant.minimalClean:
        return _ProfilePalette(
          backgroundGradient: const [
            Color(0xFFF8F8FA),
            Color(0xFFF4F4F7),
            Color(0xFFF1F2F6),
          ],
          appBarColor: const Color(0xFFF8F8FA),
          primaryText: const Color(0xFF111827),
          panelColor: Colors.white,
          panelBorderColor: const Color(0xFFD5D9E2),
          panelShadowColor: const Color(0x15000000),
          panelGlowColor: const Color(0x14090909),
          sectionCardColor: const Color(0xFFF7F8FB),
          sectionCardBorderColor: const Color(0xFFD7DFEB),
          statChipColor: const Color(0xFF111111),
          statChipTextColor: Colors.white,
          listItemCardColor: Colors.white,
          listItemCardBorderColor: const Color(0xFFDDE2EB),
          variantChipColor: const Color(0xFFF0F2F6),
          variantChipBorderColor: const Color(0xFFD7DFEB),
          variantChipTextColor: const Color(0xFF6B7280),
          variantChipActiveColor: const Color(0xFF111111),
          variantChipActiveTextColor: Colors.white,
        );
    }
  }
}

class _InstagramStat extends StatelessWidget {
  const _InstagramStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
