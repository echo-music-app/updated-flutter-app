import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/core/widgets/trend_surfaces.dart';
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
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: appTrendBackground(context),
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
              _CenterStateCard(
                icon: Icons.notifications_none_rounded,
                title: 'All caught up',
                subtitle: 'No notifications right now.',
              ),
            ],
          ),
        );
      case NotificationsState.error:
        return _CenterStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load notifications',
          subtitle: 'Please try again.',
          actionLabel: 'Retry',
          onAction: widget.viewModel.load,
        );
      case NotificationsState.authRequired:
        return _CenterStateCard(
          icon: Icons.lock_clock_outlined,
          title: 'Session expired',
          subtitle: 'Please login again.',
          actionLabel: 'Go to login',
          onAction: () => context.go(Routes.login),
        );
      case NotificationsState.data:
        final totalCount =
            widget.viewModel.activities.length +
            widget.viewModel.requests.length;
        final items = <Widget>[];
        items.add(
          _SummaryCard(
            totalCount: totalCount,
            requestsCount: widget.viewModel.requests.length,
            activityCount: widget.viewModel.activities.length,
          ),
        );
        if (widget.viewModel.activities.isNotEmpty) {
          items.add(
            _SectionLabel(
              title: 'Post Activity',
              count: widget.viewModel.activities.length,
            ),
          );
          items.addAll(
            widget.viewModel.activities.map(
              (activity) => _NotificationCard(
                leadingText: activity.actorUsername,
                title: activity.actorUsername,
                subtitle: _activitySubtitle(activity),
                trailing: Text(
                  _shortDate(activity.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          );
        }

        if (widget.viewModel.requests.isNotEmpty) {
          items.add(
            _SectionLabel(
              title: 'Follow Requests',
              count: widget.viewModel.requests.length,
            ),
          );
          items.addAll(
            widget.viewModel.requests.map(
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
          );
        }

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

  String _shortDate(DateTime value) {
    final now = DateTime.now();
    final isToday =
        now.year == value.year &&
        now.month == value.month &&
        now.day == value.day;
    if (isToday) {
      final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
      final minute = value.minute.toString().padLeft(2, '0');
      final suffix = value.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }
    return '${value.month}/${value.day}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.requestsCount,
    required this.activityCount,
  });

  final int totalCount;
  final int requestsCount;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.92),
            scheme.tertiary.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$totalCount update(s) for you',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _SummaryPill(label: 'Requests $requestsCount'),
          const SizedBox(width: 6),
          _SummaryPill(label: 'Activity $activityCount'),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterStateCard extends StatelessWidget {
  const _CenterStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TrendPanel(
        child: SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 34),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    return TrendPanel(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            leadingText.isEmpty ? '?' : leadingText[0].toUpperCase(),
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
