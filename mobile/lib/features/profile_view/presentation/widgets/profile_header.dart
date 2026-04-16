import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({
    super.key,
    required this.header,
    this.localAvatarPath,
    this.onEditBio,
    this.onEditPhoto,
    this.canEdit = false,
  });

  final ProfileHeader header;
  final String? localAvatarPath;
  final VoidCallback? onEditBio;
  final VoidCallback? onEditPhoto;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final usernameInitial = header.username.isNotEmpty
        ? header.username[0].toUpperCase()
        : '?';
    final imageProvider = _profileImageProvider();

    final gradientColors = isLight
        ? const [Color(0xFFF9FBFF), Color(0xFFEFF4FF)]
        : const [Color(0xFF1E232D), Color(0xFF161B23)];
    final borderColor = isLight
        ? const Color(0xFFD8E2F0)
        : const Color(0xFF2D3442);
    final mutedTextColor = isLight
        ? const Color(0xFF5F6C80)
        : const Color(0xFFAAB3C4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    label: l10n.profileImagePlaceholderLabel,
                    child: GestureDetector(
                      onTap: canEdit ? onEditPhoto : null,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: isLight
                                ? const Color(0xFFDDE6F4)
                                : const Color(0xFF30394B),
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? Text(
                                    usernameInitial,
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          if (canEdit)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? const Color(0xFFE9EFF9)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header.username,
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          header.bio?.isNotEmpty == true
                              ? header.bio!
                              : l10n.profileEmptyBioMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    InkWell(
                      onTap: onEditBio,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xFFE9EFF9)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Posts', value: _estimatedPostsCount),
                  _StatItem(label: 'Followers', value: header.followersCount),
                  _StatItem(label: 'Following', value: header.followingCount),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'My Posts',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.profileGenresSectionTitle,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        header.preferredGenres.isEmpty
            ? Text(
                l10n.profileEmptyGenresMessage,
                style: textTheme.bodyMedium?.copyWith(color: mutedTextColor),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: header.preferredGenres.map((g) {
                  return Chip(
                    label: Text(g),
                    backgroundColor: isLight
                        ? const Color(0xFFE9EFF9)
                        : const Color(0xFF2A3342),
                    labelStyle: TextStyle(
                      color: isLight ? const Color(0xFF111827) : Colors.white,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  int get _estimatedPostsCount => 0;

  ImageProvider<Object>? _profileImageProvider() {
    final path = localAvatarPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final url = header.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }

    return null;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      children: [
        Text(
          _comma(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isLight ? const Color(0xFF5F6C80) : const Color(0xFFAAB3C4),
          ),
        ),
      ],
    );
  }

  String _comma(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      b.write(s[i]);
      final fromEnd = s.length - i - 1;
      if (fromEnd > 0 && fromEnd % 3 == 0) b.write(',');
    }
    return b.toString();
  }
}
