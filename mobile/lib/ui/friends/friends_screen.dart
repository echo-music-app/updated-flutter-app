import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
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
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
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
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _buildBody(context),
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
        return RefreshIndicator(
          onRefresh: widget.viewModel.load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: widget.viewModel.friends.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final friend = widget.viewModel.friends[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend.avatarUrl != null
                      ? NetworkImage(friend.avatarUrl!)
                      : null,
                  child: friend.avatarUrl == null
                      ? Text(
                          friend.username.isNotEmpty
                              ? friend.username[0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                title: Text(friend.username),
                subtitle: Text(
                  widget.listType == FriendListType.followers
                      ? 'Follower'
                      : 'Following',
                ),
                onTap: () => context.push(
                  '${Routes.profile}/${Uri.encodeComponent(friend.userId)}',
                ),
              );
            },
          ),
        );
    }
  }
}
