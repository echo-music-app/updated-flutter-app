enum SearchResultType { tracks, albums, artists }

enum SearchScreenStatus { idle, loading, data, empty, error, authRequired }

class MusicSearchQuery {
  MusicSearchQuery({required this.raw}) : trimmed = raw.trim();

  final String raw;
  final String trimmed;

  bool get isValid => trimmed.isNotEmpty;
}

class ResultAttribution {
  const ResultAttribution({
    required this.source,
    required this.sourceItemId,
    this.sourceUrl,
  });

  final String source;
  final String sourceItemId;
  final String? sourceUrl;
}

class TrackSearchResult {
  const TrackSearchResult({
    required this.id,
    required this.displayName,
    this.primaryCreatorName,
    this.durationMs,
    this.playableLink,
    this.artworkUrl,
    required this.sources,
    required this.relevanceScore,
  });

  final String id;
  final String displayName;
  final String? primaryCreatorName;
  final int? durationMs;
  final String? playableLink;
  final String? artworkUrl;
  final List<ResultAttribution> sources;
  final double relevanceScore;
}

class AlbumSearchResult {
  const AlbumSearchResult({
    required this.id,
    required this.displayName,
    this.primaryCreatorName,
    this.artworkUrl,
    required this.sources,
    required this.relevanceScore,
  });

  final String id;
  final String displayName;
  final String? primaryCreatorName;
  final String? artworkUrl;
  final List<ResultAttribution> sources;
  final double relevanceScore;
}

class ArtistSearchResult {
  const ArtistSearchResult({
    required this.id,
    required this.displayName,
    this.artworkUrl,
    required this.sources,
    required this.relevanceScore,
  });

  final String id;
  final String displayName;
  final String? artworkUrl;
  final List<ResultAttribution> sources;
  final double relevanceScore;
}

class MusicSearchSummary {
  const MusicSearchSummary({
    required this.totalCount,
    required this.perTypeCounts,
    required this.perSourceCounts,
    required this.sourceStatuses,
    required this.isPartial,
    required this.warnings,
  });

  final int totalCount;
  final Map<String, int> perTypeCounts;
  final Map<String, int> perSourceCounts;
  final Map<String, String> sourceStatuses;
  final bool isPartial;
  final List<String> warnings;
}

class MusicSearchResultGroup {
  const MusicSearchResultGroup({
    required this.query,
    required this.limit,
    required this.tracks,
    required this.albums,
    required this.artists,
    required this.summary,
  });

  final String query;
  final int limit;
  final List<TrackSearchResult> tracks;
  final List<AlbumSearchResult> albums;
  final List<ArtistSearchResult> artists;
  final MusicSearchSummary summary;
}

class MusicSearchViewState {
  const MusicSearchViewState({
    this.status = SearchScreenStatus.idle,
    this.selectedType = SearchResultType.tracks,
    this.activeQuery = '',
    this.results,
    this.errorMessageKey,
  });

  final SearchScreenStatus status;
  final SearchResultType selectedType;
  final String activeQuery;
  final MusicSearchResultGroup? results;
  final String? errorMessageKey;

  MusicSearchViewState copyWith({
    SearchScreenStatus? status,
    SearchResultType? selectedType,
    String? activeQuery,
    MusicSearchResultGroup? results,
    bool clearResults = false,
    String? errorMessageKey,
    bool clearError = false,
  }) {
    return MusicSearchViewState(
      status: status ?? this.status,
      selectedType: selectedType ?? this.selectedType,
      activeQuery: activeQuery ?? this.activeQuery,
      results: clearResults ? null : (results ?? this.results),
      errorMessageKey: clearError
          ? null
          : (errorMessageKey ?? this.errorMessageKey),
    );
  }
}
