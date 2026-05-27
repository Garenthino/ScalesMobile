import 'package:scales_mobile/domain/entities/singer_profile.dart';

/// Repository that defines singer profile operations.
abstract class SingerProfileRepository {
  Future<SingerProfile> fetchProfile(String singerId);
  Future<SingerProfile> updateProfile(String singerId, {
    String? name,
    String? bio,
    String? avatarUrl,
  });
  Future<List<SongHistoryItem>> fetchSongHistory(String singerId);
  Future<List<SongHistoryItem>> fetchFavoriteSongs(String singerId);
  Future<void> addFavoriteSong(String singerId, SongHistoryItem song);
  Future<void> removeFavoriteSong(String singerId, String songId);
}

/// Repository for check-in operations.
abstract class CheckInRepository {
  Future<CheckInResult> checkIn(String venueId, String singerId, {String? code});
  Future<CheckInResult> getCurrentCheckIn(String singerId);
}

/// Repository for leaderboard.
abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> fetchLeaderboard(String venueId, {int limit = 20});
}

/// Repository for social features.
abstract class SocialRepository {
  Future<void> follow(String followerId, String followeeId);
  Future<void> unfollow(String followerId, String followeeId);
  Future<bool> isFollowing(String followerId, String followeeId);
  Future<void> shareToSocial(SocialShare share);
}
