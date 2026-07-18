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

/// History item for a past queue request.
class QueueHistoryItem {
  final String requestId;
  final String songTitle;
  final String songArtist;
  final String? genre;
  final String status;
  final String requestedAt;
  final String? playedAt;
  final String? notes;
  final String? rejectReason;

  const QueueHistoryItem({
    required this.requestId,
    required this.songTitle,
    required this.songArtist,
    this.genre,
    required this.status,
    required this.requestedAt,
    this.playedAt,
    this.notes,
    this.rejectReason,
  });
}

/// Paginated history result.
class QueueHistoryResult {
  final List<QueueHistoryItem> items;
  final int total;
  final int page;
  final int perPage;

  const QueueHistoryResult({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
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
