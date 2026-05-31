import 'package:image_picker/image_picker.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';

/// Repository that defines singer profile operations.
abstract class SingerProfileRepository {
  /// Fetch any singer profile by ID (venue-scoped).
  Future<SingerProfile> fetchProfile(String singerId);

  /// Fetch own profile via GET /me (no singerId needed).
  Future<SingerProfile> fetchMyProfile();

  /// Update own profile via PUT /me.
  Future<SingerProfile> updateMyProfile({
    String? stageName,
    String? realName,
    String? pronouns,
    String? phone,
    String? bio,
    List<SocialLink>? socialLinks,
  });

  /// Upload avatar via POST /me/avatar with multipart upload.
  /// Returns the new avatar URL.
  Future<String?> uploadAvatar(
    XFile image, {
    void Function(double progress)? onProgress,
  });

  /// Fetch own stats via GET /me/stats.
  Future<SingerStats> fetchMyStats();

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
  Future<List<LeaderboardEntry>> fetchLeaderboard(String venueId, {int limit = 20, String? period});
}

/// Repository for social features.
abstract class SocialRepository {
  Future<void> follow(String followerId, String followeeId);
  Future<void> unfollow(String followerId, String followeeId);
  Future<bool> isFollowing(String followerId, String followeeId);
  Future<void> shareToSocial(SocialShare share);
}
