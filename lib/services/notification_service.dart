import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:scales_mobile/domain/entities/notification.dart';
import 'package:scales_mobile/domain/repositories/notification_repository.dart';
import 'package:scales_mobile/services/firebase_options.dart';

/// Top-level handler for background FCM messages.
/// Must be a top-level function (not a class method) so Firebase can invoke it
/// in a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background messages don't need UI updates; just log.
  debugPrint('[FCM-bg] ${message.messageId} \u2192 ${message.notification?.title}');
}

/// Service that manages Firebase Cloud Messaging lifecycle:
///   • Initialize Firebase + FCM
///   • Request permissions (iOS)
///   • Register device token with backend
///   • Handle foreground messages → local notifications
///   • Handle notification taps → deep-link routing
///   • Handle data-only messages for real-time queue updates
class NotificationService {
  final NotificationRepository _repository;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// Callback invoked when a notification is tapped.
  /// Receives the [NotificationRoute] and optional payload map.
  void Function(NotificationRoute, Map<String, dynamic>?)? onNotificationTap;

  /// Callback invoked for foreground data-only messages that affect the queue.
  void Function(Map<String, dynamic>)? onQueueDataMessage;

  NotificationService({
    required NotificationRepository repository,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _repository = repository,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize Firebase, request permissions, set up listeners.
  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS only; Android is granted by default for data messages)
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Android notification channel for local notifications
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'scales_high_importance_channel',
        'Scales Notifications',
        description: 'Real-time karaoke queue alerts and venue updates',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Initialize local notifications plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification-opened-app (tapped while app was in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundTap);

    _initialized = true;
  }

  /// Register the FCM token with the backend (called after login / startup).
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _repository.registerDeviceToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }
  }

  /// Unregister token on logout.
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _repository.unregisterDeviceToken(token);
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] unregisterToken error: $e');
    }
  }

  /// Listen for token refresh and re-register.
  void listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _repository.registerDeviceToken(
          token,
          platform: Platform.isIOS ? 'ios' : 'android',
        );
      } catch (e) {
        debugPrint('[FCM] token refresh error: $e');
      }
    });
  }

  // ------------------------------------------------------------------
  // Handlers
  // ------------------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    // Data-only message for queue updates (no notification body)
    if (notification == null && data.isNotEmpty) {
      final type = data['type']?.toString() ?? '';
      if (type == 'queue_update' || type == 'up_soon' || type == 'bumped' || type == 'on_stage') {
        onQueueDataMessage?.call(data);
      }
      return;
    }

    // Display local notification for foreground messages
    if (notification != null) {
      _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'Scales',
        body: notification.body ?? '',
        payload: jsonEncode(data),
      );
    }
  }

  void _handleBackgroundTap(RemoteMessage message) {
    final data = message.data;
    final typeStr = data['type']?.toString() ?? 'unknown';
    final route = _routeFromString(typeStr);
    if (route != NotificationRoute.none) {
      onNotificationTap?.call(route, data);
    }
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final typeStr = data['type']?.toString() ?? 'unknown';
      final route = _routeFromString(typeStr);
      if (route != NotificationRoute.none) {
        onNotificationTap?.call(route, data);
      }
    } catch (_) {
      // ignore malformed payload
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'scales_high_importance_channel',
          'Scales Notifications',
          channelDescription: 'Real-time karaoke queue alerts and venue updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  NotificationRoute _routeFromString(String value) {
    switch (value.toLowerCase()) {
      case 'up_soon':
      case 'bumped':
      case 'queue_update':
        return NotificationRoute.queue;
      case 'on_stage':
      case 'announcement':
        return NotificationRoute.home;
      case 'social':
        return NotificationRoute.singerProfile;
      case 'payment':
        return NotificationRoute.singerProfile;
      default:
        return NotificationRoute.none;
    }
  }
}
