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
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';

class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key, required this.viewModel});

  final MusicSearchViewModel viewModel;

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final _controller = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.viewModel.search(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const AppTopNavLeading(),
        title: Text(l10n.searchTitle),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Semantics(
                    label: l10n.searchSubmitLabel,
                    child: TextField(
                      controller: _controller,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: l10n.searchInputHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_controller.text.trim().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              tooltip: l10n.searchSubmitLabel,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
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
        final resultCount = _countForSelectedType(state);
        return Column(
          children: [
            if (state.activeQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Showing $resultCount result(s) for "${state.activeQuery}"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
            onTap: () =>
                context.push('${Routes.profile}/${results.users[i].id}'),
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

  int _countForSelectedType(MusicSearchViewState state) {
    final results = state.results;
    if (results == null) return 0;
    switch (state.selectedType) {
      case SearchResultType.tracks:
        return results.tracks.length;
      case SearchResultType.albums:
        return results.albums.length;
      case SearchResultType.artists:
        return results.artists.length;
      case SearchResultType.users:
        return results.users.length;
    }
  }
}
