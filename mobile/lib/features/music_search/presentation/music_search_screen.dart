import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/features/music_search/presentation/music_search_view_model.dart';
import 'package:mobile/features/music_search/presentation/widgets/album_search_result_tile.dart';
import 'package:mobile/features/music_search/presentation/widgets/artist_search_result_tile.dart';
import 'package:mobile/features/music_search/presentation/widgets/track_search_result_tile.dart';
import 'package:mobile/features/music_search/presentation/widgets/user_search_result_tile.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';

class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key, required this.viewModel});

  final MusicSearchViewModel viewModel;

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.viewModel.search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Semantics(
              label: l10n.searchSubmitLabel,
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: l10n.searchInputHint,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: l10n.searchSubmitLabel,
                    onPressed: _submit,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) =>
                  _buildBody(context, widget.viewModel.state, l10n),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentTab: AppBottomNavTab.search,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MusicSearchViewState state,
    AppLocalizations l10n,
  ) {
    switch (state.status) {
      case SearchScreenStatus.idle:
        return Center(child: Text(l10n.searchIdlePrompt));

      case SearchScreenStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case SearchScreenStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.searchErrorMessage),
              SizedBox(height: AppSpacing.md),
              Semantics(
                label: l10n.searchRetryLabel,
                child: ElevatedButton(
                  onPressed: widget.viewModel.retryLastQuery,
                  child: Text(l10n.searchRetryLabel),
                ),
              ),
            ],
          ),
        );

      case SearchScreenStatus.authRequired:
        return Center(child: Text(l10n.searchAuthRequiredMessage));

      case SearchScreenStatus.data:
      case SearchScreenStatus.empty:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Semantics(
                label: l10n.searchSegmentControlLabel,
                child: SegmentedButton<SearchResultType>(
                  segments: [
                    ButtonSegment(
                      value: SearchResultType.tracks,
                      label: Text(l10n.searchSegmentTracks),
                    ),
                    ButtonSegment(
                      value: SearchResultType.albums,
                      label: Text(l10n.searchSegmentAlbums),
                    ),
                    ButtonSegment(
                      value: SearchResultType.artists,
                      label: Text(l10n.searchSegmentArtists),
                    ),
                    const ButtonSegment(
                      value: SearchResultType.users,
                      label: Text('Users'),
                    ),
                  ],
                  selected: {state.selectedType},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      widget.viewModel.selectType(selection.first);
                    }
                  },
                ),
              ),
            ),
            Expanded(child: _buildResultList(context, state, l10n)),
          ],
        );
    }
  }

  Widget _buildResultList(
    BuildContext context,
    MusicSearchViewState state,
    AppLocalizations l10n,
  ) {
    if (state.status == SearchScreenStatus.empty) {
      return Center(child: Text(_emptyMessage(state.selectedType, l10n)));
    }

    final results = state.results;
    if (results == null) return const SizedBox.shrink();

    switch (state.selectedType) {
      case SearchResultType.tracks:
        return ListView.builder(
          itemCount: results.tracks.length,
          itemBuilder: (_, i) =>
              TrackSearchResultTile(track: results.tracks[i]),
        );
      case SearchResultType.albums:
        return ListView.builder(
          itemCount: results.albums.length,
          itemBuilder: (_, i) =>
              AlbumSearchResultTile(album: results.albums[i]),
        );
      case SearchResultType.artists:
        return ListView.builder(
          itemCount: results.artists.length,
          itemBuilder: (_, i) =>
              ArtistSearchResultTile(artist: results.artists[i]),
        );
      case SearchResultType.users:
        return ListView.builder(
          itemCount: results.users.length,
          itemBuilder: (_, i) => UserSearchResultTile(
            user: results.users[i],
            onTap: () => context.go('${Routes.profile}/${results.users[i].id}'),
          ),
        );
    }
  }

  String _emptyMessage(SearchResultType type, AppLocalizations l10n) {
    switch (type) {
      case SearchResultType.tracks:
        return l10n.searchTracksEmptyMessage;
      case SearchResultType.albums:
        return l10n.searchAlbumsEmptyMessage;
      case SearchResultType.artists:
        return l10n.searchArtistsEmptyMessage;
      case SearchResultType.users:
        return 'No users found';
    }
  }
}
