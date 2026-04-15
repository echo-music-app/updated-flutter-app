import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_sidebar_drawer.dart';
import 'package:mobile/ui/notifications/notifications_view_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.viewModel});

  final NotificationsViewModel viewModel;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Open menu',
          onPressed: () => showAppSidebar(context),
        ),
        title: const Text('Notifications'),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _buildBody(context),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.viewModel.state) {
      case NotificationsState.loading:
        return const Center(child: CircularProgressIndicator());
      case NotificationsState.empty:
        return const Center(child: Text('No follow requests right now.'));
      case NotificationsState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load notifications.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.viewModel.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case NotificationsState.authRequired:
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
      case NotificationsState.data:
        return ListView.separated(
          itemCount: widget.viewModel.requests.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final request = widget.viewModel.requests[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  request.requesterUsername.isEmpty
                      ? '?'
                      : request.requesterUsername[0].toUpperCase(),
                ),
              ),
              title: Text(request.requesterUsername),
              subtitle: const Text('Sent you a follow request'),
              trailing: FilledButton(
                onPressed: widget.viewModel.isProcessing
                    ? null
                    : () => _acceptRequest(request.requesterUserId),
                child: const Text('Accept'),
              ),
            );
          },
        );
    }
  }

  Future<void> _acceptRequest(String requesterUserId) async {
    final ok = await widget.viewModel.acceptRequest(requesterUserId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Follow request accepted.' : 'Could not accept request.',
        ),
      ),
    );
  }
}
