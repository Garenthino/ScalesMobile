/// Core user entity (singer, host, or admin).
/// TODO(Garenthino): Migrate to freezed codegen when Sprint 1 data layer is wired.
class UserEntity {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final UserRole role;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.role,
    this.createdAt,
  });
}

enum UserRole { singer, host, admin, venueManager }

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

enum SongStatus { pending, inProgress, completed, cancelled }
