import '../../domain/entities/notification.dart';

/// Repository for device token and notification history.
abstract class NotificationRepository {
  /// Register an FCM device token with the backend.
  Future<void> registerDeviceToken(String token, {String? platform});

  /// Unregister the current device token.
  Future<void> unregisterDeviceToken(String token);

  /// Fetch notification history for the current singer.
  Future<List<AppNotification>> fetchNotifications({int limit = 50, int offset = 0});

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId);

  /// Mark all notifications as read.
  Future<void> markAllAsRead();

  /// Fetch unread count.
  Future<int> fetchUnreadCount();

  /// Update push settings on the backend.
  Future<void> updateSettings(NotificationSettings settings);

  /// Fetch saved settings from backend (or local fallback).
  Future<NotificationSettings> fetchSettings();
}
