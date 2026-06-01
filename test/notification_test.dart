import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/domain/entities/notification.dart';
import 'package:scales_mobile/presentation/providers/notification_provider.dart';

void main() {
  group('AppNotification', () {
    test('copyWith updates only specified fields', () {
      final n = AppNotification(
        id: '1',
        title: 'Up Soon',
        body: 'You are next in queue',
        type: NotificationType.upSoon,
        receivedAt: DateTime(2026, 1, 1),
        read: false,
      );

      final updated = n.copyWith(read: true);
      expect(updated.id, '1');
      expect(updated.title, 'Up Soon');
      expect(updated.read, true);
    });

    test('notification route mapping', () {
      final queueN = AppNotification(
        id: '1',
        title: 't',
        body: 'b',
        type: NotificationType.bumped,
        receivedAt: DateTime.now(),
        route: NotificationRoute.queue,
      );
      expect(queueN.route, NotificationRoute.queue);

      final homeN = AppNotification(
        id: '2',
        title: 't',
        body: 'b',
        type: NotificationType.onStage,
        receivedAt: DateTime.now(),
        route: NotificationRoute.home,
      );
      expect(homeN.route, NotificationRoute.home);
    });
  });

  group('NotificationSettings', () {
    test('defaults are all true', () {
      const s = NotificationSettings();
      expect(s.upSoon, true);
      expect(s.onStage, true);
      expect(s.bumped, true);
      expect(s.announcement, true);
      expect(s.social, true);
      expect(s.queueUpdate, true);
      expect(s.payment, true);
    });

    test('copyWith toggles a single field', () {
      const s = NotificationSettings();
      final updated = s.copyWith(upSoon: false);
      expect(updated.upSoon, false);
      expect(updated.onStage, true);
    });

    test('copyWith preserves unchanged fields', () {
      const s = NotificationSettings(payment: false);
      final updated = s.copyWith(social: false);
      expect(updated.payment, false);
      expect(updated.social, false);
      expect(updated.upSoon, true);
    });
  });

  group('NotificationListState', () {
    test('unreadCount counts only unread items', () {
      final state = NotificationListState(notifications: [
        AppNotification(
          id: '1', title: 'a', body: 'b',
          type: NotificationType.upSoon, receivedAt: DateTime.now(), read: false,
        ),
        AppNotification(
          id: '2', title: 'a', body: 'b',
          type: NotificationType.onStage, receivedAt: DateTime.now(), read: true,
        ),
        AppNotification(
          id: '3', title: 'a', body: 'b',
          type: NotificationType.bumped, receivedAt: DateTime.now(), read: false,
        ),
      ]);
      expect(state.unreadCount, 2);
    });

    test('empty state has zero unread', () {
      const state = NotificationListState();
      expect(state.unreadCount, 0);
    });
  });

  group('NotificationSettingsState', () {
    test('default settings are all enabled', () {
      const state = NotificationSettingsState();
      expect(state.settings.upSoon, true);
      expect(state.settings.onStage, true);
      expect(state.isLoading, false);
    });

    test('loading state', () {
      const state = NotificationSettingsState(isLoading: true);
      expect(state.isLoading, true);
      expect(state.error, null);
    });
  });
}
