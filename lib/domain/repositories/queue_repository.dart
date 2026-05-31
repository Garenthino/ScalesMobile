import 'package:scales_mobile/domain/entities/queue_request.dart';

/// Repository for singer-facing queue operations.
abstract class QueueRepository {
  Future<QueueJoinResult> joinQueue({
    required String venueId,
    required String songId,
    String? notes,
  });

  Future<List<QueueStatusItem>> fetchMyQueueStatus({required String venueId});

  Future<int> leaveQueue({required String venueId, String? requestId});

  Future<PublicQueue> fetchVenueQueue({required String venueId});
}
