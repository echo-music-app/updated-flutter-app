import 'package:flutter/material.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';

class ArtistSearchResultTile extends StatelessWidget {
  const ArtistSearchResultTile({super.key, required this.artist});

  final ArtistSearchResult artist;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: artist.displayName,
      container: true,
      excludeSemantics: true,
      child: ListTile(
        leading: _artwork(artist.artworkUrl),
        title: Text(artist.displayName),
      ),
    );
  }

  Widget _artwork(String? url) {
    if (url == null) {
      return const Icon(Icons.person);
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.person),
      ),
    );
  }
}
