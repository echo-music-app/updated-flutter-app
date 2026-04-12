import 'package:flutter/material.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

class TrackSearchResultTile extends StatelessWidget {
  const TrackSearchResultTile({super.key, required this.track});

  final TrackSearchResult track;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = track.primaryCreatorName ?? l10n.unknownArtist;
    return Semantics(
      label: '${track.displayName}, $subtitle',
      container: true,
      excludeSemantics: true,
      child: ListTile(
        leading: _artwork(track.artworkUrl),
        title: Text(track.displayName),
        subtitle: Text(subtitle),
        trailing: track.durationMs != null
            ? Text(_formatDuration(track.durationMs!))
            : null,
      ),
    );
  }

  Widget _artwork(String? url) {
    if (url == null) {
      return const Icon(Icons.music_note);
    }
    return Image.network(
      url,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.music_note),
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
