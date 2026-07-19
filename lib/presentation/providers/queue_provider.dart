import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/datasources/api_client.dart';
import 'package:scales_mobile/data/repositories/queue_repository.dart';
import 'package:scales_mobile/domain/entities/queue_request.dart';
import 'package:scales_mobile/domain/repositories/queue_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepositoryImpl(dio: ref.watch(dioProvider));
});

final activeVenueProvider = FutureProvider.autoDispose<CachedVenue?>((
  ref,
) async {
  final storage = await VenueStorage.create();
  return storage.getActiveVenue();
});

final myQueueProvider = FutureProvider.autoDispose
    .family<List<QueueStatusItem>, String>((ref, venueId) async {
      final repository = ref.watch(queueRepositoryProvider);
      return repository.fetchMyQueueStatus(venueId: venueId);
    });

final myQueueHistoryProvider = FutureProvider.autoDispose
    .family<QueueHistoryResult, String>((ref, venueId) async {
      final repository = ref.watch(queueRepositoryProvider);
      return repository.fetchMyQueueHistory(venueId: venueId);
    });

final cancelRequestProvider = Provider.autoDispose
    .family<Future<void> Function(String requestId), String>((ref, venueId) {
  return (String requestId) async {
    final repository = ref.read(queueRepositoryProvider);
    await repository.cancelRequest(venueId: venueId, requestId: requestId);
    ref.invalidate(myQueueProvider(venueId));
  };
});
