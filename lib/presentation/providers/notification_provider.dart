import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/datasources/api_client.dart';
import 'package:scales_mobile/data/repositories/notification_repository.dart';
import 'package:scales_mobile/domain/entities/notification.dart';
import 'package:scales_mobile/domain/repositories/notification_repository.dart';
import 'package:scales_mobile/services/notification_service.dart';

// ------------------------------------------------------------------
// Repository provider
// ------------------------------------------------------------------
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(dio: ref.watch(dioProvider));
});

// ------------------------------------------------------------------
// Service provider (lazy singleton)
// ------------------------------------------------------------------
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationService(repository: repo);
});

// ------------------------------------------------------------------
// Notification list state
// ------------------------------------------------------------------
class NotificationListState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationListState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.read).length;
}

class NotificationListNotifier extends Notifier<NotificationListState> {
  late final NotificationRepository _repo;

  @override
  NotificationListState build() {
    _repo = ref.read(notificationRepositoryProvider);
    _load();
    return const NotificationListState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final items = await _repo.fetchNotifications();
      state = NotificationListState(notifications: items);
    } catch (e) {
      state = NotificationListState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = const NotificationListState(isLoading: true);
    await _load();
  }

  /// Mark a single notification as read (optimistic update + backend sync).
  Future<void> markAsRead(String id) async {
    final prev = state.notifications;
    final updated = prev.map((n) {
      if (n.id == id) return n.copyWith(read: true);
      return n;
    }).toList();
    state = NotificationListState(notifications: updated);
    try {
      await _repo.markAsRead(id);
    } catch (_) {
      // Rollback on failure
      state = NotificationListState(notifications: prev);
    }
  }

  /// Mark all as read.
  Future<void> markAllAsRead() async {
    final prev = state.notifications;
    final updated = prev.map((n) => n.copyWith(read: true)).toList();
    state = NotificationListState(notifications: updated);
    try {
      await _repo.markAllAsRead();
    } catch (_) {
      state = NotificationListState(notifications: prev);
    }
  }

  /// Append a real-time notification from a foreground FCM message.
  void addNotification(AppNotification notification) {
    final current = state.notifications;
    // Prevent duplicates by id
    if (current.any((n) => n.id == notification.id)) return;
    state = NotificationListState(
      notifications: [notification, ...current],
    );
  }
}

final notificationListProvider =
    NotifierProvider<NotificationListNotifier, NotificationListState>(
  NotificationListNotifier.new,
);

// ------------------------------------------------------------------
// Unread count provider (separate for cheap rebuilds)
// ------------------------------------------------------------------
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.fetchUnreadCount();
});

// ------------------------------------------------------------------
// Settings state
// ------------------------------------------------------------------
class NotificationSettingsState {
  final NotificationSettings settings;
  final bool isLoading;
  final String? error;

  const NotificationSettingsState({
    this.settings = const NotificationSettings(),
    this.isLoading = false,
    this.error,
  });
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  late final NotificationRepository _repo;

  @override
  NotificationSettingsState build() {
    _repo = ref.read(notificationRepositoryProvider);
    _load();
    return const NotificationSettingsState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final settings = await _repo.fetchSettings();
      state = NotificationSettingsState(settings: settings);
    } catch (e) {
      state = NotificationSettingsState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = const NotificationSettingsState(isLoading: true);
    await _load();
  }

  /// Toggle a single notification type.
  Future<void> toggle(NotificationType type, bool value) async {
    final current = state.settings;
    NotificationSettings updated;
    switch (type) {
      case NotificationType.upSoon:
        updated = current.copyWith(upSoon: value);
      case NotificationType.onStage:
        updated = current.copyWith(onStage: value);
      case NotificationType.bumped:
        updated = current.copyWith(bumped: value);
      case NotificationType.announcement:
        updated = current.copyWith(announcement: value);
      case NotificationType.social:
        updated = current.copyWith(social: value);
      case NotificationType.queueUpdate:
        updated = current.copyWith(queueUpdate: value);
      case NotificationType.payment:
        updated = current.copyWith(payment: value);
      case NotificationType.unknown:
        return;
    }
    state = NotificationSettingsState(settings: updated);
    try {
      await _repo.updateSettings(updated);
    } catch (e) {
      // Rollback
      state = NotificationSettingsState(settings: current, error: e.toString());
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);

// ------------------------------------------------------------------
// Convenience: per-type enabled provider
// ------------------------------------------------------------------
final isNotificationTypeEnabledProvider =
    Provider.family<bool, NotificationType>((ref, type) {
  final state = ref.watch(notificationSettingsProvider);
  final s = state.settings;
  return switch (type) {
    NotificationType.upSoon => s.upSoon,
    NotificationType.onStage => s.onStage,
    NotificationType.bumped => s.bumped,
    NotificationType.announcement => s.announcement,
    NotificationType.social => s.social,
    NotificationType.queueUpdate => s.queueUpdate,
    NotificationType.payment => s.payment,
    NotificationType.unknown => false,
  };
});
