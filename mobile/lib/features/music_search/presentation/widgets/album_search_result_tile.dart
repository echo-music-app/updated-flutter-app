import 'package:flutter/material.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

class AlbumSearchResultTile extends StatelessWidget {
  const AlbumSearchResultTile({super.key, required this.album});

  final AlbumSearchResult album;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = album.primaryCreatorName ?? l10n.unknownArtist;
    return Semantics(
      label: '${album.displayName}, $subtitle',
      container: true,
      excludeSemantics: true,
      child: ListTile(
        leading: _artwork(album.artworkUrl),
        title: Text(album.displayName),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _artwork(String? url) {
    if (url == null) {
      return const Icon(Icons.album);
    }
    return Image.network(
      url,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.album),
    );
  }
}
