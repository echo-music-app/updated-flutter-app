import 'package:flutter/material.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({super.key, required this.header});

  final ProfileHeader header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: l10n.profileImagePlaceholderLabel,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    header.username.isNotEmpty
                        ? header.username[0].toUpperCase()
                        : '?',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(header.username, style: textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.profileBioSectionTitle, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            header.bio?.isNotEmpty == true
                ? header.bio!
                : l10n.profileEmptyBioMessage,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(l10n.profileGenresSectionTitle, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          header.preferredGenres.isEmpty
              ? Text(
                  l10n.profileEmptyGenresMessage,
                  style: textTheme.bodyMedium,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: header.preferredGenres
                      .map((g) => Chip(label: Text(g)))
                      .toList(),
                ),
        ],
      ),
    );
  }
}
