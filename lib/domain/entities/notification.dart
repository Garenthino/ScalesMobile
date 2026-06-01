/// Types of push notifications the app can receive.
enum NotificationType {
  /// Singer is second in queue — up soon.
  upSoon,
  /// Singer is now on stage.
  onStage,
  /// Singer's queue position was bumped by priority payment.
  bumped,
  /// General venue announcement.
  announcement,
  /// Social interaction (follow, tip, etc.).
  social,
  /// Queue status update (general).
  queueUpdate,
  /// Payment confirmation.
  payment,
  /// Unknown / fallback.
  unknown,
}

/// Deep-link route a notification should open when tapped.
enum NotificationRoute {
  queue,
  songBrowser,
  singerProfile,
  leaderboard,
  checkIn,
  home,
  none,
}

/// Domain entity for an in-app notification.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime receivedAt;
  /// Whether the user has seen / read this notification.
  final bool read;
  /// Payload data from the push (e.g. queue_position, venue_id).
  final Map<String, dynamic>? payload;
  /// Route to navigate to when tapped.
  final NotificationRoute? route;
  /// Optional image URL for rich notifications.
  final String? imageUrl;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.read = false,
    this.payload,
    this.route,
    this.imageUrl,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? receivedAt,
    bool? read,
    Map<String, dynamic>? payload,
    NotificationRoute? route,
    String? imageUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      receivedAt: receivedAt ?? this.receivedAt,
      read: read ?? this.read,
      payload: payload ?? this.payload,
      route: route ?? this.route,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Per-type notification settings for the user.
class NotificationSettings {
  final bool upSoon;
  final bool onStage;
  final bool bumped;
  final bool announcement;
  final bool social;
  final bool queueUpdate;
  final bool payment;

  const NotificationSettings({
    this.upSoon = true,
    this.onStage = true,
    this.bumped = true,
    this.announcement = true,
    this.social = true,
    this.queueUpdate = true,
    this.payment = true,
  });

  NotificationSettings copyWith({
    bool? upSoon,
    bool? onStage,
    bool? bumped,
    bool? announcement,
    bool? social,
    bool? queueUpdate,
    bool? payment,
  }) {
    return NotificationSettings(
      upSoon: upSoon ?? this.upSoon,
      onStage: onStage ?? this.onStage,
      bumped: bumped ?? this.bumped,
      announcement: announcement ?? this.announcement,
      social: social ?? this.social,
      queueUpdate: queueUpdate ?? this.queueUpdate,
      payment: payment ?? this.payment,
    );
  }
}
