import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/core/widgets/trend_surfaces.dart';
import 'package:mobile/ui/friends/friends_repository.dart';
import 'package:mobile/ui/friends/friends_view_model.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.viewModel,
    required this.listType,
  });

  final FriendsViewModel viewModel;
  final FriendListType listType;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppTopNavLeading(),
        title: Text(
          widget.listType == FriendListType.followers
              ? 'Followers'
              : 'Following',
        ),
      ),
      body: DecoratedBox(
        decoration: appTrendBackground(context),
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) => _buildBody(context),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentTab: AppBottomNavTab.profile,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.viewModel.state) {
      case FriendsState.loading:
        return const Center(child: CircularProgressIndicator());
      case FriendsState.empty:
        return RefreshIndicator(
          onRefresh: widget.viewModel.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Text(
                    widget.listType == FriendListType.followers
                        ? 'No followers yet.'
                        : 'Not following anyone yet.',
                  ),
                ),
              ),
            ],
          ),
        );
      case FriendsState.error:
        return RefreshIndicator(
          onRefresh: widget.viewModel.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.listType == FriendListType.followers
                            ? 'Could not load followers.'
                            : 'Could not load following list.',
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: widget.viewModel.load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case FriendsState.authRequired:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session expired. Please login again.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('Go to login'),
              ),
            ],
          ),
        );
      case FriendsState.data:
        final filteredFriends = widget.viewModel.friends
            .where((friend) {
              final q = _query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return friend.username.toLowerCase().contains(q);
            })
            .toList(growable: false);
        return RefreshIndicator(
          onRefresh: widget.viewModel.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.listType == FriendListType.followers
                      ? 'Search followers'
                      : 'Search following',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              TrendPanel(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredFriends.length} user(s)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (filteredFriends.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('No users match your search.')),
                )
              else
                ...filteredFriends.map(
                  (friend) => Column(
                    children: [
                      TrendPanel(
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: AppAvatar(
                            radius: 20,
                            imageProvider: friend.avatarUrl != null
                                ? NetworkImage(friend.avatarUrl!)
                                : null,
                            fallbackText: friend.username.isNotEmpty
                                ? friend.username[0].toUpperCase()
                                : '?',
                          ),
                          title: Text(friend.username),
                          subtitle: Text(
                            widget.listType == FriendListType.followers
                                ? 'Follower'
                                : 'Following',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            '${Routes.profile}/${Uri.encodeComponent(friend.userId)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
            ],
          ),
        );
    }
  }
}
