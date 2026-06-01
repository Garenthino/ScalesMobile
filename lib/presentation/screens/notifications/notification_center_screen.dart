import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/notification.dart';
import 'package:scales_mobile/presentation/providers/notification_provider.dart';

/// In-app notification center — lists push notifications with unread/read state.
/// Tap navigates to the relevant screen based on notification type.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  Future<void> _onRefresh() async {
    await ref.read(notificationListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationListProvider.notifier).markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorView(error: state.error!, onRetry: _onRefresh)
              : state.notifications.isEmpty
                  ? const _EmptyView()
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        itemCount: state.notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final n = state.notifications[index];
                          return _NotificationTile(
                            notification: n,
                            onTap: () => _onTap(context, n),
                            onDismiss: () => ref
                                .read(notificationListProvider.notifier)
                                .markAsRead(n.id),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'notification_settings',
        onPressed: () => context.push(RoutePaths.notificationSettings),
        child: const Icon(Icons.settings),
      ),
    );
  }

  void _onTap(BuildContext context, AppNotification n) {
    // Mark as read immediately
    ref.read(notificationListProvider.notifier).markAsRead(n.id);

    final route = n.route;
    if (route == null || route == NotificationRoute.none) return;

    switch (route) {
      case NotificationRoute.queue:
        context.push(RoutePaths.singerQueue);
      case NotificationRoute.songBrowser:
        context.push(RoutePaths.songBrowser);
      case NotificationRoute.singerProfile:
        context.push(RoutePaths.singerProfile);
      case NotificationRoute.leaderboard:
        context.push(RoutePaths.leaderboard);
      case NotificationRoute.checkIn:
        context.push(RoutePaths.checkIn);
      case NotificationRoute.home:
        context.push(RoutePaths.home);
      case NotificationRoute.none:
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.read;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUnread
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            _typeIcon(notification.type),
            color: isUnread
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          notification.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, h:mm a').format(notification.receivedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }

  IconData _typeIcon(NotificationType type) {
    return switch (type) {
      NotificationType.upSoon => Icons.access_time,
      NotificationType.onStage => Icons.mic,
      NotificationType.bumped => Icons.trending_up,
      NotificationType.announcement => Icons.campaign,
      NotificationType.social => Icons.people,
      NotificationType.queueUpdate => Icons.queue_music,
      NotificationType.payment => Icons.payments,
      NotificationType.unknown => Icons.notifications,
    };
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off,
              size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
