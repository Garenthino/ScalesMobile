import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/domain/entities/notification.dart';
import 'package:scales_mobile/presentation/providers/notification_provider.dart';

/// Profile > Notification Settings screen.
///
/// Allows the user to enable/disable each notification type individually.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorView(error: state.error!, onRetry: () {
                  ref.read(notificationSettingsProvider.notifier).refresh();
                })
              : ListView(
                  children: [
                    _ToggleTile(
                      icon: Icons.access_time,
                      title: 'Up Soon',
                      subtitle: 'Notify when you are second in queue',
                      value: state.settings.upSoon,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.upSoon, v),
                    ),
                    _ToggleTile(
                      icon: Icons.mic,
                      title: 'On Stage',
                      subtitle: 'Notify when you are called to perform',
                      value: state.settings.onStage,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.onStage, v),
                    ),
                    _ToggleTile(
                      icon: Icons.trending_up,
                      title: 'Priority Bump',
                      subtitle: 'Notify when your position is bumped',
                      value: state.settings.bumped,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.bumped, v),
                    ),
                    _ToggleTile(
                      icon: Icons.queue_music,
                      title: 'Queue Updates',
                      subtitle: 'General queue position and ETA changes',
                      value: state.settings.queueUpdate,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.queueUpdate, v),
                    ),
                    _ToggleTile(
                      icon: Icons.campaign,
                      title: 'Announcements',
                      subtitle: 'Venue-wide news and events',
                      value: state.settings.announcement,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.announcement, v),
                    ),
                    _ToggleTile(
                      icon: Icons.people,
                      title: 'Social',
                      subtitle: 'Follows, tips, and interactions',
                      value: state.settings.social,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.social, v),
                    ),
                    _ToggleTile(
                      icon: Icons.payments,
                      title: 'Payments',
                      subtitle: 'Payment confirmations and receipts',
                      value: state.settings.payment,
                      onChanged: (v) => ref
                          .read(notificationSettingsProvider.notifier)
                          .toggle(NotificationType.payment, v),
                    ),
                  ],
                ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
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
