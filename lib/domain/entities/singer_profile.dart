/// A top-song entry returned by /me/stats.
class TopSong {
  final String id;
  final String title;
  final String? artist;
  final int count;

  const TopSong({
    required this.id,
    required this.title,
    this.artist,
    required this.count,
  });
}

/// Comprehensive singer stats from /me/stats.
class SingerStats {
  final int songsSung;
  final int totalCheckins;
  final int totalPoints;
  final List<TopSong> topSongs;
  final double? avgWaitMin;
  final String? favoriteGenre;

  const SingerStats({
    required this.songsSung,
    required this.totalCheckins,
    required this.totalPoints,
    required this.topSongs,
    this.avgWaitMin,
    this.favoriteGenre,
  });
}

/// Social link entry for a singer profile.
class SocialLink {
  final String platform;
  final String url;

  const SocialLink({required this.platform, required this.url});
}

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
  final String? realName; // legacy full display name (server-derived)
  final String? firstName;
  final String? lastName;
  final String? pronouns;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final List<SocialLink> socialLinks;
  final bool isCheckedIn;
  final DateTime? checkedInAt;
  final int performancesCount;
  final int followersCount;
  final int followingCount;
  final LoyaltyTier tier;
  final List<SongHistoryItem> songHistory;
  final List<SongHistoryItem> favoriteSongs;

  const SingerProfile({
    required this.id,
    required this.name,
    this.realName,
    this.firstName,
    this.lastName,
    this.pronouns,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.socialLinks = const [],
    this.isCheckedIn = false,
    this.checkedInAt,
    required this.performancesCount,
    required this.followersCount,
    required this.followingCount,
    required this.tier,
    required this.songHistory,
    required this.favoriteSongs,
  });

  String get displayName => name;

  SingerProfile copyWith({
    String? name,
    String? realName,
    String? firstName,
    String? lastName,
    String? pronouns,
    String? phone,
    String? bio,
    String? avatarUrl,
    List<SocialLink>? socialLinks,
    bool? isCheckedIn,
    DateTime? checkedInAt,
    int? performancesCount,
    int? followersCount,
    int? followingCount,
    LoyaltyTier? tier,
    List<SongHistoryItem>? songHistory,
    List<SongHistoryItem>? favoriteSongs,
  }) {
    return SingerProfile(
      id: id,
      name: name ?? this.name,
      realName: realName ?? this.realName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      pronouns: pronouns ?? this.pronouns,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      socialLinks: socialLinks ?? this.socialLinks,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      performancesCount: performancesCount ?? this.performancesCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      tier: tier ?? this.tier,
      songHistory: songHistory ?? this.songHistory,
      favoriteSongs: favoriteSongs ?? this.favoriteSongs,
    );
  }
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
