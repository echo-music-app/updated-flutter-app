import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';

class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({
    super.key,
    required this.header,
    required this.postsCount,
    this.localAvatarPath,
    this.onEditBio,
    this.onEditPhoto,
    this.onTapFollowers,
    this.onTapFollowing,
    this.canEdit = false,
  });

  final ProfileHeader header;
  final int postsCount;
  final String? localAvatarPath;
  final VoidCallback? onEditBio;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onTapFollowers;
  final VoidCallback? onTapFollowing;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usernameInitial = header.username.isNotEmpty
        ? header.username[0].toUpperCase()
        : '?';
    final imageProvider = _profileImageProvider();

    final mutedTextColor = colorScheme.onSurfaceVariant;
    final surfaceColor = colorScheme.surfaceContainerLowest;
    final borderColor = colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
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
                          AppAvatar(
                            radius: 34,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            imageProvider: imageProvider,
                            fallbackText: usernameInitial,
                            fallbackTextStyle: textTheme.headlineSmall
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (canEdit)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: colorScheme.onSurface,
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
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 18,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Posts', value: postsCount),
                  _StatItem(
                    label: 'Followers',
                    value: header.followersCount,
                    onTap: onTapFollowers,
                  ),
                  _StatItem(
                    label: 'Following',
                    value: header.followingCount,
                    onTap: onTapFollowing,
                  ),
                ],
              ),
            ],
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
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    labelStyle: TextStyle(color: colorScheme.onSurface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

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
  const _StatItem({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
