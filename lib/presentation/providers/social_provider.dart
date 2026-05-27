import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/repositories/social_repository.dart';
import 'package:scales_mobile/data/repositories/leaderboard_repository.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

final socialRepoProvider = Provider<SocialRepository>(
  (_) => SocialRepositoryImpl(),
);

final leaderboardRepoProvider = Provider<LeaderboardRepository>(
  (_) => LeaderboardRepositoryImpl(),
);

/// Provider for fetching leaderboard data for a venue.
final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, venueId) async {
  final repo = ref.watch(leaderboardRepoProvider);
  return repo.fetchLeaderboard(venueId);
});
