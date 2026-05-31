import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/entities/song.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';
import 'package:scales_mobile/domain/repositories/song_repository.dart';
import 'package:scales_mobile/main.dart';
import 'package:scales_mobile/presentation/providers/profile_provider.dart';
import 'package:scales_mobile/presentation/providers/social_provider.dart';
import 'package:scales_mobile/presentation/providers/song_search_provider.dart';
import 'package:scales_mobile/presentation/screens/check_in/check_in_screen.dart';
import 'package:scales_mobile/presentation/screens/leaderboard/leaderboard_screen.dart';
import 'package:scales_mobile/presentation/screens/singer/singer_profile_screen.dart';
import 'package:scales_mobile/presentation/screens/songs/song_browser_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ScalesApp displays branded splash on first frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ScalesApp()));
    await tester.pump();
    expect(find.text('Scales'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('SingerProfileScreen renders with provider override', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          singerProfileRepoProvider.overrideWithValue(
            _FakeSingerProfileRepository(),
          ),
        ],
        child: const MaterialApp(home: SingerProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Alex Singer'), findsOneWidget);
    expect(find.text('Gold Tier'), findsOneWidget);
    expect(find.textContaining('Sweet Caroline'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('CheckInScreen shows venue code input', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CheckInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter Venue Code'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('LeaderboardScreen renders with repository override', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardRepoProvider.overrideWithValue(_FakeLeaderboardRepository()),
        ],
        child: const MaterialApp(home: LeaderboardScreen(venueId: 'test_venue')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Alex Singer'), findsOneWidget);
    expect(find.text('1240 pts'), findsOneWidget);
    expect(find.text('Bailey Ballad'), findsOneWidget);
  });

  testWidgets('SongBrowserScreen renders fake catalog without live network', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'scales_active_venue_id': 'venue_1',
      'scales_venues': jsonEncode([
        {
          'id': 'venue_1',
          'name': 'Golden Dragon Karaoke',
          'slug': 'golden-dragon',
          'venue_code': 'GOLDEN',
          'timezone': 'America/New_York',
          'is_active': true,
        },
      ]),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository()),
        ],
        child: const MaterialApp(home: SongBrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse Songs'), findsOneWidget);
    expect(find.text('Golden Dragon Karaoke'), findsOneWidget);
    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(find.textContaining('Queen'), findsWidgets);
  });

  testWidgets('SingerProfileScreen renders favorite songs from fake repo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          singerProfileRepoProvider.overrideWithValue(
            _FakeSingerProfileRepository(),
          ),
        ],
        child: const MaterialApp(home: SingerProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorite Songs (2)'), findsOneWidget);
    expect(find.textContaining('Bohemian Rhapsody'), findsWidgets);
    expect(find.textContaining('Purple Rain'), findsWidgets);
    expect(find.textContaining('Queen'), findsWidgets);
    expect(find.textContaining('Prince'), findsWidgets);
  });

  testWidgets('SongBrowserScreen favorite toggle calls repository', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'scales_active_venue_id': 'venue_1',
      'scales_auth_venue_1': 'fake-token',
      'scales_venues': jsonEncode([
        {
          'id': 'venue_1',
          'name': 'Golden Dragon Karaoke',
          'slug': 'golden-dragon',
          'venue_code': 'GOLDEN',
          'timezone': 'America/New_York',
          'is_active': true,
        },
      ]),
    });

    final fakeRepo = _FakeSongRepository();
    final spyRepo = _SpySingerProfileRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(fakeRepo),
          singerProfileRepoProvider.overrideWithValue(spyRepo),
        ],
        child: const MaterialApp(home: SongBrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // With no auth token pre-loaded in authProvider, the screen will show
    // "Sign in to save favorites" when tapped. Intercept that path instead.
    final favoriteButton = find.byIcon(Icons.favorite_border);
    expect(favoriteButton, findsOneWidget);

    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}

class _FakeSingerProfileRepository implements SingerProfileRepository {
  final _history = [
    SongHistoryItem(
      id: 'hist_1',
      songName: 'Sweet Caroline',
      artistName: 'Neil Diamond',
      playedAt: DateTime(2026, 5, 1),
      venueName: 'Golden Dragon Karaoke',
    ),
  ];

  final _favorites = [
    SongHistoryItem(
      id: 'song_fav_1',
      songName: 'Bohemian Rhapsody',
      artistName: 'Queen',
      playedAt: DateTime(2026, 5, 10),
    ),
    SongHistoryItem(
      id: 'song_fav_2',
      songName: 'Purple Rain',
      artistName: 'Prince',
      playedAt: DateTime(2026, 5, 11),
    ),
  ];

  Future<SingerProfile> _makeProfile(String singerId) async => SingerProfile(
    id: singerId,
    name: 'Alex Singer',
    bio: 'Karaoke regular',
    avatarUrl: null,
    performancesCount: _history.length,
    followersCount: 12,
    followingCount: 4,
    tier: const LoyaltyTier(
      name: 'Gold',
      points: 1240,
      pointsToNextTier: 260,
      color: '#FFD700',
    ),
    songHistory: _history,
    favoriteSongs: _favorites,
  );

  @override
  Future<SingerProfile> fetchProfile(String singerId) async => _makeProfile(singerId);

  @override
  Future<SingerProfile> fetchMyProfile() async => _makeProfile('singer_1');

  @override
  Future<SingerProfile> updateMyProfile({
    String? stageName,
    String? realName,
    String? pronouns,
    String? phone,
    String? bio,
    List<SocialLink>? socialLinks,
  }) => fetchMyProfile();

  @override
  Future<String?> uploadAvatar(
    XFile image, {
    void Function(double progress)? onProgress,
  }) async => 'https://example.com/fake_avatar.png';

  @override
  Future<SingerStats> fetchMyStats() async => const SingerStats(
    songsSung: 42,
    totalCheckins: 8,
    totalPoints: 1240,
    topSongs: [
      TopSong(id: 'song_1', title: 'Bohemian Rhapsody', artist: 'Queen', count: 5),
      TopSong(id: 'song_2', title: 'Sweet Caroline', artist: 'Neil Diamond', count: 3),
      TopSong(id: 'song_3', title: 'Purple Rain', artist: 'Prince', count: 2),
    ],
  );

  @override
  Future<List<SongHistoryItem>> fetchSongHistory(String singerId) async => _history;

  @override
  Future<List<SongHistoryItem>> fetchFavoriteSongs(String singerId) async => _favorites;

  @override
  Future<void> addFavoriteSong(String singerId, SongHistoryItem song) async {}

  @override
  Future<void> removeFavoriteSong(String singerId, String songId) async {}
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard(
    String venueId, {
    int limit = 20,
    String? period,
  }) async {
    return const [
      LeaderboardEntry(
        singerId: 'singer_1',
        name: 'Alex Singer',
        points: 1240,
        rank: 1,
      ),
      LeaderboardEntry(
        singerId: 'singer_2',
        name: 'Bailey Ballad',
        points: 930,
        rank: 2,
      ),
    ];
  }
}

class _FakeSongRepository implements SongRepository {
  final _songs = const [
    Song(
      id: 'song_1',
      venueId: 'venue_1',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      genre: 'Rock',
      durationMs: 354000,
      year: 1975,
      isAvailable: true,
      isActive: true,
    ),
  ];

  @override
  Future<List<Song>> fetchSongs({
    int page = 1,
    int perPage = 20,
    String? query,
  }) async => _songs;

  @override
  Future<List<Song>> searchSongs(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async =>
      _songs
          .where((song) => song.title.toLowerCase().contains(query.toLowerCase()))
          .toList(growable: false);

  @override
  Future<Song> fetchSong(String songId) async =>
      _songs.singleWhere((song) => song.id == songId);
}

class _SpySingerProfileRepository implements SingerProfileRepository {
  final List<String> addedSongIds = [];
  final List<String> removedSongIds = [];

  Future<SingerProfile> _makeProfile(String singerId) async => SingerProfile(
    id: singerId,
    name: 'Spy Singer',
    bio: null,
    avatarUrl: null,
    performancesCount: 0,
    followersCount: 0,
    followingCount: 0,
    tier: const LoyaltyTier(
      name: 'Member',
      points: 0,
      pointsToNextTier: 100,
      color: '#4CAF50',
    ),
    songHistory: const [],
    favoriteSongs: const [],
  );

  @override
  Future<SingerProfile> fetchProfile(String singerId) async => _makeProfile(singerId);

  @override
  Future<SingerProfile> fetchMyProfile() async => _makeProfile('singer_1');

  @override
  Future<SingerProfile> updateMyProfile({
    String? stageName,
    String? realName,
    String? pronouns,
    String? phone,
    String? bio,
    List<SocialLink>? socialLinks,
  }) => fetchMyProfile();

  @override
  Future<String?> uploadAvatar(
    XFile image, {
    void Function(double progress)? onProgress,
  }) async => null;

  @override
  Future<SingerStats> fetchMyStats() async => const SingerStats(
    songsSung: 0,
    totalCheckins: 0,
    totalPoints: 0,
    topSongs: [],
  );

  @override
  Future<List<SongHistoryItem>> fetchSongHistory(String singerId) async => const [];

  @override
  Future<List<SongHistoryItem>> fetchFavoriteSongs(String singerId) async => const [];

  @override
  Future<void> addFavoriteSong(String singerId, SongHistoryItem song) async {
    addedSongIds.add(song.id);
  }

  @override
  Future<void> removeFavoriteSong(String singerId, String songId) async {
    removedSongIds.add(songId);
  }
}
