import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/repositories/check_in_repository.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

final checkInRepoProvider = Provider<CheckInRepository>(
  (_) => CheckInRepositoryImpl(),
);

/// Provider for current check-in state.
final currentCheckInProvider = FutureProvider.autoDispose
    .family<CheckInResult, String>((ref, singerId) async {
  final repo = ref.watch(checkInRepoProvider);
  return repo.getCurrentCheckIn(singerId);
});

/// Simple provider to perform a check-in and return result.
final checkInActionProvider = FutureProvider.autoDispose
    .family<CheckInResult, ({String venueId, String singerId, String? code})>(
  (ref, args) async {
    final repo = ref.read(checkInRepoProvider);
    return repo.checkIn(args.venueId, args.singerId, code: args.code);
  },
);
