import 'package:scales_mobile/domain/entities/queue_request.dart';

/// Aggregated view of a single song's performance history.
///
/// Provides the data needed by the History tab UI: one row per unique song
/// with the total number of completed performances and the most recent time
/// it was sung.
class AggregatedHistorySong {
  final String songTitle;
  final String songArtist;
  final String? genre;
  final int count;
  final DateTime? lastSungAt;
  final String? lastRequestId;

  const AggregatedHistorySong({
    required this.songTitle,
    required this.songArtist,
    this.genre,
    required this.count,
    this.lastSungAt,
    this.lastRequestId,
  });
}

/// Aggregates raw queue history into one entry per unique song.
///
/// - Rejected and skipped requests are excluded (they were not performed).
/// - Songs are grouped by a normalized `artist::title` key.
/// - [count] is the number of non-rejected/skipped occurrences.
/// - [lastSungAt] is the latest `playedAt` timestamp, falling back to
///   `requestedAt` when `playedAt` is unavailable.
/// - Results are sorted by most recent [lastSungAt] first.
List<AggregatedHistorySong> aggregateQueueHistory(
  List<QueueHistoryItem> items,
) {
  final map = <String, AggregatedHistorySong>{};

  for (final item in items) {
    if (item.status == 'rejected' || item.status == 'skipped') continue;

    final key = _normalizeKey(item.songArtist, item.songTitle);
    final existing = map[key];
    final itemDate = _parseTimestamp(item.playedAt ?? item.requestedAt);

    if (existing == null) {
      map[key] = AggregatedHistorySong(
        songTitle: item.songTitle,
        songArtist: item.songArtist,
        genre: item.genre,
        count: 1,
        lastSungAt: itemDate,
        lastRequestId: item.requestId,
      );
    } else {
      final isNewer = itemDate != null &&
          (existing.lastSungAt == null || itemDate.isAfter(existing.lastSungAt!));

      map[key] = AggregatedHistorySong(
        songTitle: existing.songTitle,
        songArtist: existing.songArtist,
        genre: existing.genre,
        count: existing.count + 1,
        lastSungAt: isNewer ? itemDate : existing.lastSungAt,
        lastRequestId: isNewer ? item.requestId : existing.lastRequestId,
      );
    }
  }

  final list = map.values.toList(growable: false);
  list.sort(
    (a, b) => (b.lastSungAt ?? _epoch).compareTo(a.lastSungAt ?? _epoch),
  );
  return list;
}

String _normalizeKey(String artist, String title) {
  return '${artist.trim().toLowerCase()}::${title.trim().toLowerCase()}';
}

DateTime? _parseTimestamp(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);
