import 'dart:math';

import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

// Mock implementation of singer profile repository using local memory.
// Switches to real API once backend endpoints are available.

class SingerProfileRepositoryImpl implements SingerProfileRepository {
  @override
  Future<SingerProfile> fetchProfile(String singerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _makeProfile(singerId);
  }

  @override
  Future<SingerProfile> updateProfile(
    String singerId, {
    String? name,
    String? bio,
    String? avatarUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Return updated profile with mocked changes
    final base = _makeProfile(singerId);
    return SingerProfile(
      id: base.id,
      name: name ?? base.name,
      bio: bio ?? base.bio,
      avatarUrl: avatarUrl ?? base.avatarUrl,
      performancesCount: base.performancesCount,
      followersCount: base.followersCount,
      followingCount: base.followingCount,
      tier: base.tier,
      songHistory: base.songHistory,
      favoriteSongs: base.favoriteSongs,
    );
  }

  @override
  Future<List<SongHistoryItem>> fetchSongHistory(String singerId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _makeSongHistory();
  }

  @override
  Future<List<SongHistoryItem>> fetchFavoriteSongs(String singerId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _makeSongHistory().sublist(0, min(3, _makeSongHistory().length));
  }

  @override
  Future<void> addFavoriteSong(String singerId, SongHistoryItem song) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> removeFavoriteSong(String singerId, String songId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  SingerProfile _makeProfile(String singerId) {
    return SingerProfile(
      id: singerId,
      name: singerId == 'demo_user' ? 'Alex Singer' : 'Jane Doe',
      bio: 'Karaoke enthusiast and shower superstar.',
      avatarUrl: null,
      performancesCount: 42,
      followersCount: 15,
      followingCount: 8,
      tier: const LoyaltyTier(
        name: 'Gold',
        points: 420,
        pointsToNextTier: 80,
        color: '#FFD700',
      ),
      songHistory: _makeSongHistory(),
      favoriteSongs: _makeSongHistory().sublist(0, 3),
    );
  }

  List<SongHistoryItem> _makeSongHistory() {
    return [
      SongHistoryItem(
        id: 'song_1',
        songName: 'Bohemian Rhapsody',
        artistName: 'Queen',
        playedAt: DateTime.now().subtract(const Duration(days: 2)),
        venueName: 'The Golden Mic',
      ),
      SongHistoryItem(
        id: 'song_2',
        songName: 'Bad Romance',
        artistName: 'Lady Gaga',
        playedAt: DateTime.now().subtract(const Duration(days: 5)),
        venueName: 'Karaoke Central',
      ),
      SongHistoryItem(
        id: 'song_3',
        songName: 'Hotel California',
        artistName: 'Eagles',
        playedAt: DateTime.now().subtract(const Duration(days: 12)),
        venueName: 'The Golden Mic',
      ),
    ];
  }
}
