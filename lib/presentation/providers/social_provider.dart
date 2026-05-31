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
/// Optionally accepts a period ('week', 'month', 'alltime').
final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, ({String venueId, String period})>((ref, args) async {
  final repo = ref.watch(leaderboardRepoProvider);
  return repo.fetchLeaderboard(args.venueId, period: args.period == 'alltime' ? null : args.period);
});

/// Provider for follow status lookup: bool for a given followeeId.
final followStatusProvider = FutureProvider.autoDispose
    .family<bool, ({String followerId, String followeeId})>((ref, args) async {
  final repo = ref.watch(socialRepoProvider);
  return repo.isFollowing(args.followerId, args.followeeId);
});

/// Mutation provider that exposes follow/unfollow operations and invalidates status.
final followMutationProvider = Provider<FollowMutation>((ref) {
  return FollowMutation(
    repo: ref.read(socialRepoProvider),
    invalidate: (followerId, followeeId) {
      ref.invalidate(
        followStatusProvider(
          (followerId: followerId, followeeId: followeeId),
        ),
      );
      ref.invalidate(leaderboardProvider);
    },
  );
});

class FollowMutation {
  final SocialRepository _repo;
  final void Function(String, String) _invalidate;

  const FollowMutation({
    required this._repo,
    required this._invalidate,
  });

  Future<void> follow(String followerId, String followeeId) async {
    await _repo.follow(followerId, followeeId);
    _invalidate(followerId, followeeId);
  }

  Future<void> unfollow(String followerId, String followeeId) async {
    await _repo.unfollow(followerId, followeeId);
    _invalidate(followerId, followeeId);
  }
}
