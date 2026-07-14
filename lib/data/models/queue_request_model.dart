import 'package:scales_mobile/data/models/song_model.dart';
import 'package:scales_mobile/domain/entities/queue_request.dart';

/// Request body for POST /venues/{venue_id}/queue/join.
class QueueJoinRequestModel {
  final String songId;
  final String? notes;

  const QueueJoinRequestModel({required this.songId, this.notes});

  Map<String, dynamic> toJson() => {
    'song_id': songId,
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
  };
}

/// Model helpers for singer-facing queue responses.
class QueueJoinResultModel extends QueueJoinResult {
  const QueueJoinResultModel({
    required super.requestId,
    required super.estimatedPosition,
    super.warning,
  });

  factory QueueJoinResultModel.fromJson(Map<String, dynamic> json) {
    return QueueJoinResultModel(
      requestId: json['request_id']?.toString() ?? '',
      estimatedPosition: _intValue(json['estimated_position']),
      warning: json['warning']?.toString(),
    );
  }
}

class QueueStatusItemModel extends QueueStatusItem {
  const QueueStatusItemModel({
    required super.requestId,
    required super.position,
    required super.status,
    required super.songTitle,
    required super.songArtist,
    super.etaSeconds,
  });

  factory QueueStatusItemModel.fromJson(Map<String, dynamic> json) {
    return QueueStatusItemModel(
      requestId: json['request_id']?.toString() ?? '',
      position: _intValue(json['position']),
      status: json['status']?.toString() ?? 'pending',
      songTitle: json['song_title']?.toString() ?? 'Unknown song',
      songArtist: json['song_artist']?.toString() ?? 'Unknown artist',
      etaSeconds: _intOrNull(json['eta_seconds']),
    );
  }
}

class PublicQueueItemModel extends PublicQueueItem {
  const PublicQueueItemModel({
    required super.position,
    required super.status,
    required super.songTitle,
    required super.songArtist,
    required super.stageName,
    super.estimatedStart,
  });

  factory PublicQueueItemModel.fromJson(Map<String, dynamic> json) {
    return PublicQueueItemModel(
      position: _intValue(json['position']),
      status: json['status']?.toString() ?? 'pending',
      songTitle: json['song_title']?.toString() ?? 'Unknown song',
      songArtist: json['song_artist']?.toString() ?? 'Unknown artist',
      stageName: json['stage_name']?.toString() ?? json['display_name']?.toString() ?? 'Singer',
      estimatedStart: _dateOrNull(json['estimated_start']),
    );
  }
}

class PublicQueueModel extends PublicQueue {
  const PublicQueueModel({
    required super.venueId,
    required super.items,
    super.currentSong,
  });

  factory PublicQueueModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawCurrentSong = json['current_song'];
    return PublicQueueModel(
      venueId: json['venue_id']?.toString() ?? '',
      items: rawItems is List<dynamic>
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(PublicQueueItemModel.fromJson)
                .toList(growable: false)
          : const [],
      currentSong: rawCurrentSong is Map<String, dynamic>
          ? SongModel.fromJson(rawCurrentSong)
          : null,
    );
  }
}

class QueueHistoryItemModel extends QueueHistoryItem {
  const QueueHistoryItemModel({
    required super.requestId,
    required super.songTitle,
    required super.songArtist,
    super.genre,
    required super.status,
    required super.requestedAt,
    super.playedAt,
    super.notes,
  });

  factory QueueHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return QueueHistoryItemModel(
      requestId: json['request_id']?.toString() ?? '',
      songTitle: json['song_title']?.toString() ?? 'Unknown song',
      songArtist: json['song_artist']?.toString() ?? 'Unknown artist',
      genre: json['genre']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      requestedAt: json['requested_at']?.toString() ?? '',
      playedAt: json['played_at']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class QueueHistoryResultModel extends QueueHistoryResult {
  const QueueHistoryResultModel({
    required super.items,
    required super.total,
    required super.page,
    required super.perPage,
  });

  factory QueueHistoryResultModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return QueueHistoryResultModel(
      items: rawItems is List<dynamic>
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(QueueHistoryItemModel.fromJson)
                .toList(growable: false)
          : const [],
      total: _intValue(json['total']),
      page: _intValue(json['page']),
      perPage: _intValue(json['per_page']),
    );
  }
}

int _intValue(Object? value) => _intOrNull(value) ?? 0;

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
