import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/domain/entities/queue_request.dart';
import 'package:scales_mobile/domain/usecases/aggregate_history.dart';

void main() {
  group('aggregateQueueHistory', () {
    test('returns one row per unique song with count and lastSungAt', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'Sweet Caroline',
          artist: 'Neil Diamond',
          status: 'completed',
          requestedAt: '2026-01-01T20:00:00Z',
          playedAt: '2026-01-01T20:05:00Z',
        ),
        _historyItem(
          requestId: 'r2',
          title: 'Sweet Caroline',
          artist: 'Neil Diamond',
          status: 'completed',
          requestedAt: '2026-01-02T20:00:00Z',
          playedAt: '2026-01-02T20:05:00Z',
        ),
        _historyItem(
          requestId: 'r3',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          status: 'completed',
          requestedAt: '2026-01-03T20:00:00Z',
          playedAt: '2026-01-03T20:10:00Z',
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result, hasLength(2));
      final sweetCaroline = result.firstWhere(
        (s) => s.songTitle == 'Sweet Caroline',
      );
      expect(sweetCaroline.count, 2);
      expect(sweetCaroline.lastSungAt, DateTime.parse('2026-01-02T20:05:00Z'));
      expect(sweetCaroline.lastRequestId, 'r2');

      final bohemian = result.firstWhere(
        (s) => s.songTitle == 'Bohemian Rhapsody',
      );
      expect(bohemian.count, 1);
      expect(bohemian.lastSungAt, DateTime.parse('2026-01-03T20:10:00Z'));
      expect(bohemian.lastRequestId, 'r3');
    });

    test('excludes rejected and skipped requests', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'Sweet Caroline',
          artist: 'Neil Diamond',
          status: 'rejected',
          requestedAt: '2026-01-01T20:00:00Z',
          playedAt: null,
        ),
        _historyItem(
          requestId: 'r2',
          title: 'Sweet Caroline',
          artist: 'Neil Diamond',
          status: 'skipped',
          requestedAt: '2026-01-02T20:00:00Z',
          playedAt: null,
        ),
        _historyItem(
          requestId: 'r3',
          title: 'Sweet Caroline',
          artist: 'Neil Diamond',
          status: 'completed',
          requestedAt: '2026-01-03T20:00:00Z',
          playedAt: '2026-01-03T20:05:00Z',
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result, hasLength(1));
      expect(result.single.count, 1);
      expect(result.single.lastSungAt, DateTime.parse('2026-01-03T20:05:00Z'));
    });

    test('falls back to requestedAt when playedAt is missing', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'Hello',
          artist: 'Adele',
          status: 'completed',
          requestedAt: '2026-05-10T19:00:00Z',
          playedAt: null,
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result.single.lastSungAt, DateTime.parse('2026-05-10T19:00:00Z'));
    });

    test('sorts results by most recent lastSungAt descending', () {
      final items = [
        _historyItem(
          requestId: 'old',
          title: 'Yesterday',
          artist: 'The Beatles',
          status: 'completed',
          requestedAt: '2026-01-01T20:00:00Z',
          playedAt: '2026-01-01T20:05:00Z',
        ),
        _historyItem(
          requestId: 'newer',
          title: 'Today',
          artist: 'The Smashing Pumpkins',
          status: 'completed',
          requestedAt: '2026-06-15T21:00:00Z',
          playedAt: '2026-06-15T21:05:00Z',
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result.first.songTitle, 'Today');
      expect(result.last.songTitle, 'Yesterday');
    });

    test('groups by normalized case-insensitive artist and title', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'SWEET CAROLINE',
          artist: 'neil diamond',
          status: 'completed',
          requestedAt: '2026-01-01T20:00:00Z',
          playedAt: '2026-01-01T20:05:00Z',
        ),
        _historyItem(
          requestId: 'r2',
          title: 'Sweet Caroline',
          artist: 'Neil Diamond',
          status: 'completed',
          requestedAt: '2026-01-02T20:00:00Z',
          playedAt: '2026-01-02T20:06:00Z',
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result, hasLength(1));
      expect(result.single.count, 2);
    });

    test('returns empty list when all items are rejected/skipped', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'Song A',
          artist: 'Artist A',
          status: 'rejected',
          requestedAt: '2026-01-01T20:00:00Z',
          playedAt: null,
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result, isEmpty);
    });

    test('preserves original display title/artist casing from first occurrence', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'sweet caroline',
          artist: 'neil diamond',
          status: 'completed',
          requestedAt: '2026-01-01T20:00:00Z',
          playedAt: '2026-01-01T20:05:00Z',
        ),
        _historyItem(
          requestId: 'r2',
          title: 'SWEET CAROLINE',
          artist: 'NEIL DIAMOND',
          status: 'completed',
          requestedAt: '2026-01-02T20:00:00Z',
          playedAt: '2026-01-02T20:06:00Z',
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result.single.songTitle, 'sweet caroline');
      expect(result.single.songArtist, 'neil diamond');
    });

    test('handles malformed timestamps gracefully', () {
      final items = [
        _historyItem(
          requestId: 'r1',
          title: 'Song A',
          artist: 'Artist A',
          status: 'completed',
          requestedAt: 'not-a-date',
          playedAt: null,
        ),
        _historyItem(
          requestId: 'r2',
          title: 'Song A',
          artist: 'Artist A',
          status: 'completed',
          requestedAt: '2026-02-01T20:00:00Z',
          playedAt: '2026-02-01T20:05:00Z',
        ),
      ];

      final result = aggregateQueueHistory(items);

      expect(result.single.count, 2);
      expect(result.single.lastSungAt, DateTime.parse('2026-02-01T20:05:00Z'));
    });
  });
}

QueueHistoryItem _historyItem({
  required String requestId,
  required String title,
  required String artist,
  required String status,
  required String requestedAt,
  required String? playedAt,
}) {
  return QueueHistoryItem(
    requestId: requestId,
    songTitle: title,
    songArtist: artist,
    genre: 'Pop',
    status: status,
    requestedAt: requestedAt,
    playedAt: playedAt,
    notes: null,
    rejectReason: null,
  );
}
