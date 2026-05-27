enum UserRole { singer, host, admin, venueManager }

enum SongStatus { pending, inProgress, completed, cancelled }

/// Core user entity (singer, host, or admin).
class UserEntity {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final UserRole role;
  final DateTime? createdAt;
  final int? totalPerformances;
  final int? loyaltyPoints;
  final String? loyaltyTier;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.bio,
    required this.role,
    this.createdAt,
    this.totalPerformances,
    this.loyaltyPoints,
    this.loyaltyTier,
  });
}

/// Venue entity for browsing / search.
class VenueEntity {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  const VenueEntity({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.isActive,
    this.createdAt,
  });
}

/// Song request / queue item entity.
class SongRequestEntity {
  final String id;
  final String singerId;
  final String songName;
  final String artistName;
  final SongStatus status;
  final DateTime? submittedAt;
  final DateTime? playedAt;
  final int? queuePosition;

  const SongRequestEntity({
    required this.id,
    required this.singerId,
    required this.songName,
    required this.artistName,
    this.status = SongStatus.pending,
    this.submittedAt,
    this.playedAt,
    this.queuePosition,
  });
}
