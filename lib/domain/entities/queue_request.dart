import 'package:scales_mobile/domain/entities/song.dart';

/// Result returned after a singer joins a venue queue.
class QueueJoinResult {
  final String requestId;
  final int estimatedPosition;
  final String? warning;

  const QueueJoinResult({
    required this.requestId,
    required this.estimatedPosition,
    this.warning,
  });
}

/// Active queue status for the authenticated singer.
class QueueStatusItem {
  final String requestId;
  final int position;
  final String status;
  final String songTitle;
  final String songArtist;
  final int? etaSeconds;

  const QueueStatusItem({
    required this.requestId,
    required this.position,
    required this.status,
    required this.songTitle,
    required this.songArtist,
    this.etaSeconds,
  });
}

/// Public venue queue item without sensitive singer data.
class PublicQueueItem {
  final int position;
  final String status;
  final String songTitle;
  final String songArtist;
  final String stageName;
  final DateTime? estimatedStart;

  const PublicQueueItem({
    required this.position,
    required this.status,
    required this.songTitle,
    required this.songArtist,
    required this.stageName,
    this.estimatedStart,
  });
}

/// Public venue queue snapshot.
class PublicQueue {
  final String venueId;
  final List<PublicQueueItem> items;
  final Song? currentSong;

  const PublicQueue({
    required this.venueId,
    required this.items,
    this.currentSong,
  });
}
