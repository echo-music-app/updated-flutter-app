import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/notifications/notifications_repository.dart';
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
        leading: const AppTopNavLeading(),
        title: const Text('Notifications'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
          ),
        ),
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) => _buildBody(context),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.viewModel.state) {
      case NotificationsState.loading:
        return const Center(child: CircularProgressIndicator());
      case NotificationsState.empty:
        return RefreshIndicator(
          onRefresh: widget.viewModel.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [
              Card(
                child: SizedBox(
                  height: 220,
                  child: Center(child: Text('No notifications right now.')),
                ),
              ),
            ],
          ),
        );
      case NotificationsState.error:
        return Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
            ),
          ),
        );
      case NotificationsState.authRequired:
        return Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
            ),
          ),
        );
      case NotificationsState.data:
        final items = <Widget>[
          if (widget.viewModel.activities.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Post Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...widget.viewModel.activities.map(
              (activity) => _NotificationCard(
                leadingText: activity.actorUsername,
                title: activity.actorUsername,
                subtitle: _activitySubtitle(activity),
              ),
            ),
          ],
          if (widget.viewModel.requests.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Follow Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...widget.viewModel.requests.map(
              (request) => _NotificationCard(
                leadingText: request.requesterUsername,
                title: request.requesterUsername,
                subtitle: 'Sent you a follow request',
                trailing: FilledButton(
                  onPressed: widget.viewModel.isProcessing
                      ? null
                      : () => _acceptRequest(request.requesterUserId),
                  child: const Text('Accept'),
                ),
              ),
            ),
          ],
        ];

        return RefreshIndicator(
          onRefresh: widget.viewModel.load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => items[index],
          ),
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

  String _activitySubtitle(PostActivityNotification activity) {
    if (activity.activityType == 'comment') {
      final preview = activity.commentPreview;
      if (preview != null && preview.trim().isNotEmpty) {
        return 'Commented: "${preview.trim()}"';
      }
      return 'Commented on your post';
    }
    return 'Liked your post';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.leadingText,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String leadingText;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1E232D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            leadingText.isEmpty ? '?' : leadingText[0].toUpperCase(),
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
