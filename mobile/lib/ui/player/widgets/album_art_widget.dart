import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class AlbumArtWidget extends StatelessWidget {
  const AlbumArtWidget({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const _AlbumArtPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 300,
        height: 300,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SizedBox(
          width: 300,
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => const _AlbumArtPlaceholder(),
      ),
    );
  }
}

class _AlbumArtPlaceholder extends StatelessWidget {
  const _AlbumArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Icon(
        Icons.music_note,
        size: 80,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
