import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/notification.dart';
import 'package:scales_mobile/domain/repositories/notification_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Real implementation of [NotificationRepository] backed by the Scales API.
class NotificationRepositoryImpl implements NotificationRepository {
  final Dio _dio;

  NotificationRepositoryImpl({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiEndpoints.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  @override
  Future<void> registerDeviceToken(String token, {String? platform}) async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return;
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return;

    await _dio.post(
      '/singers/me/devices',
      data: {
        'token': token,
        'platform': platform ?? 'android',
        'device_type': 'mobile',
      },
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return;
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return;

    await _dio.delete(
      '/singers/me/devices/$token',
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  }

  @override
  Future<List<AppNotification>> fetchNotifications({int limit = 50, int offset = 0}) async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return [];
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return [];

    final response = await _dio.get(
      '/singers/me/notifications',
      queryParameters: {'limit': limit, 'offset': offset},
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );

    if (response.statusCode == StatusCodes.ok) {
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items.whereType<Map<String, dynamic>>().map(_mapNotification).toList();
    }
    return [];
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return;
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return;

    await _dio.patch(
      '/singers/me/notifications/$notificationId',
      data: {'read': true},
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  }

  @override
  Future<void> markAllAsRead() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return;
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return;

    await _dio.patch(
      '/singers/me/notifications',
      data: {'mark_all_read': true},
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return 0;
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return 0;

    final response = await _dio.get(
      '/singers/me/notifications/unread-count',
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );

    if (response.statusCode == StatusCodes.ok) {
      final data = response.data as Map<String, dynamic>;
      return data['unread_count'] as int? ?? 0;
    }
    return 0;
  }

  @override
  Future<void> updateSettings(NotificationSettings settings) async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return;
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return;

    await _dio.put(
      '/singers/me/notification-settings',
      data: {
        'up_soon': settings.upSoon,
        'on_stage': settings.onStage,
        'bumped': settings.bumped,
        'announcement': settings.announcement,
        'social': settings.social,
        'queue_update': settings.queueUpdate,
        'payment': settings.payment,
      },
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  }

  @override
  Future<NotificationSettings> fetchSettings() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return const NotificationSettings();
    final authToken = storage.getToken(venueId);
    if (authToken == null || authToken.isEmpty) return const NotificationSettings();

    final response = await _dio.get(
      '/singers/me/notification-settings',
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );

    if (response.statusCode == StatusCodes.ok) {
      final data = response.data as Map<String, dynamic>? ?? {};
      return _mapSettings(data);
    }
    return const NotificationSettings();
  }

  // ------------------------------------------------------------------
  // Mappers
  // ------------------------------------------------------------------

  AppNotification _mapNotification(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    final type = _parseType(typeStr);
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: type,
      receivedAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      route: _routeFromType(type),
      imageUrl: json['image_url']?.toString(),
    );
  }

  NotificationType _parseType(String value) {
    switch (value.toLowerCase()) {
      case 'up_soon':
        return NotificationType.upSoon;
      case 'on_stage':
        return NotificationType.onStage;
      case 'bumped':
        return NotificationType.bumped;
      case 'announcement':
        return NotificationType.announcement;
      case 'social':
        return NotificationType.social;
      case 'queue_update':
        return NotificationType.queueUpdate;
      case 'payment':
        return NotificationType.payment;
      default:
        return NotificationType.unknown;
    }
  }

  NotificationRoute _routeFromType(NotificationType type) {
    switch (type) {
      case NotificationType.upSoon:
      case NotificationType.bumped:
      case NotificationType.queueUpdate:
        return NotificationRoute.queue;
      case NotificationType.onStage:
        return NotificationRoute.home;
      case NotificationType.announcement:
        return NotificationRoute.home;
      case NotificationType.social:
        return NotificationRoute.singerProfile;
      case NotificationType.payment:
        return NotificationRoute.singerProfile;
      case NotificationType.unknown:
        return NotificationRoute.none;
    }
  }

  NotificationSettings _mapSettings(Map<String, dynamic> json) {
    return NotificationSettings(
      upSoon: json['up_soon'] as bool? ?? true,
      onStage: json['on_stage'] as bool? ?? true,
      bumped: json['bumped'] as bool? ?? true,
      announcement: json['announcement'] as bool? ?? true,
      social: json['social'] as bool? ?? true,
      queueUpdate: json['queue_update'] as bool? ?? true,
      payment: json['payment'] as bool? ?? true,
    );
  }
}
