/// Song history item for a singer's profile.
class SongHistoryItem {
  final String id;
  final String songName;
  final String artistName;
  final DateTime playedAt;
  final String? venueName;

  const SongHistoryItem({
    required this.id,
    required this.songName,
    required this.artistName,
    required this.playedAt,
    this.venueName,
  });
}

/// Singer loyalty tier info.
class LoyaltyTier {
  final String name;
  final int points;
  final int pointsToNextTier;
  final String color;

  const LoyaltyTier({
    required this.name,
    required this.points,
    required this.pointsToNextTier,
    required this.color,
  });
}

/// Full singer profile data.
class SingerProfile {
  final String id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final int performancesCount;
  final int followersCount;
  final int followingCount;
  final LoyaltyTier tier;
  final List<SongHistoryItem> songHistory;
  final List<SongHistoryItem> favoriteSongs;

  const SingerProfile({
    required this.id,
    required this.name,
    this.bio,
    this.avatarUrl,
    required this.performancesCount,
    required this.followersCount,
    required this.followingCount,
    required this.tier,
    required this.songHistory,
    required this.favoriteSongs,
  });
}

/// Check-in response.
class CheckInResult {
  final bool success;
  final String? venueId;
  final String? venueName;
  final int? queuePosition;
  final String? message;

  const CheckInResult({
    required this.success,
    this.venueId,
    this.venueName,
    this.queuePosition,
    this.message,
  });
}

/// Leaderboard entry.
class LeaderboardEntry {
  final String singerId;
  final String name;
  final String? avatarUrl;
  final int points;
  final int rank;

  const LeaderboardEntry({
    required this.singerId,
    required this.name,
    this.avatarUrl,
    required this.points,
    required this.rank,
  });
}

/// Social share payload.
class SocialShare {
  final String singerId;
  final String? songName;
  final String? artistName;
  final String platform;

  const SocialShare({
    required this.singerId,
    this.songName,
    this.artistName,
    required this.platform,
  });
}
