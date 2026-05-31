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

final myQueueStatusProvider = FutureProvider.autoDispose
    .family<List<QueueStatusItem>, String>((ref, venueId) async {
      final repository = ref.watch(queueRepositoryProvider);
      return repository.fetchMyQueueStatus(venueId: venueId);
    });
