import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/data/repositories/leaderboard_repository.dart';
import 'package:scales_mobile/data/repositories/singer_profile_repository.dart';
import 'package:scales_mobile/data/repositories/social_repository.dart';
import 'package:scales_mobile/data/repositories/song_repository.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'scales_active_venue_id': 'venue_1',
      'scales_auth_venue_1': 'test-access-token',
    });
  });

  group('SongRepositoryImpl', () {
    test('parses paginated song list data wrapper', () async {
      final dio = _dioWithRoutes({
        '/venues/venue_1/songs': _jsonResponse({
          'data': [
            _songJson(id: 'song_1', title: 'Bohemian Rhapsody'),
            _songJson(id: 'song_2', title: 'Sweet Caroline'),
          ],
          'total': 2,
        }),
      });
      final repository = SongRepositoryImpl(dio: dio);

      final songs = await repository.fetchSongs(page: 2, perPage: 10);

      expect(songs, hasLength(2));
      expect(songs.first.id, 'song_1');
      expect(songs.first.title, 'Bohemian Rhapsody');
      expect(songs.first.durationMs, 354000);
      expect(songs.first.isAvailable, isTrue);
    });

    test('parses search results wrapper and sends q/page parameters', () async {
      RequestOptions? seenRequest;
      final dio = _dioWithRoutes({
        '/venues/venue_1/songs/search': (options) {
          seenRequest = options;
          return _jsonResponse({
            'results': [_songJson(id: 'song_3', title: 'Purple Rain')],
          })(options);
        },
      });
      final repository = SongRepositoryImpl(dio: dio);

      final songs = await repository.searchSongs(' purple ', page: 3, perPage: 5);

      expect(songs.single.title, 'Purple Rain');
      expect(seenRequest?.queryParameters['q'], 'purple');
      expect(seenRequest?.queryParameters['page'], 3);
      expect(seenRequest?.queryParameters['per_page'], 5);
    });
  });

  group('SingerProfileRepositoryImpl', () {
    test('parses profile and history response wrappers', () async {
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/singer_1': _jsonResponse({
          'id': 'singer_1',
          'stage_name': 'Alex Singer',
          'bio': 'Karaoke regular',
          'total_points': 1240,
          'loyalty_tier': {
            'name': 'Gold',
            'points': 1240,
            'points_to_next_tier': 260,
            'color': '#FFD700',
          },
        }),
        '/venues/venue_1/singers/singer_1/history': _jsonResponse({
          'data': [
            {
              'id': 'hist_1',
              'song_title': 'Sweet Caroline',
              'artist': 'Neil Diamond',
              'created_at': '2026-05-01T20:30:00Z',
              'venue_name': 'Golden Dragon Karaoke',
            },
          ],
        }),
      });
      final repository = SingerProfileRepositoryImpl(dio: dio);

      final profile = await repository.fetchProfile('singer_1');

      expect(profile.id, 'singer_1');
      expect(profile.name, 'Alex Singer');
      expect(profile.tier.name, 'Gold');
      expect(profile.tier.points, 1240);
      expect(profile.songHistory.single.songName, 'Sweet Caroline');
      expect(profile.songHistory.single.artistName, 'Neil Diamond');
      expect(profile.performancesCount, 1);
    });

    test('parses paginated favorites list', () async {
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/favorites': _jsonResponse({
          'items': [
            {
              'id': 'fav_1',
              'song_id': 'song_1',
              'title': 'Bohemian Rhapsody',
              'artist': 'Queen',
              'album': 'A Night at the Opera',
              'genre': 'Rock',
              'cover_art_url': null,
              'duration_ms': 354000,
              'created_at': '2026-05-10T12:00:00Z',
            },
            {
              'id': 'fav_2',
              'song_id': 'song_2',
              'title': 'Sweet Caroline',
              'artist': 'Neil Diamond',
              'album': null,
              'genre': 'Pop',
              'cover_art_url': 'https://example.com/cover.png',
              'duration_ms': 180000,
              'created_at': '2026-05-11T08:30:00Z',
            },
          ],
          'total': 2,
          'page': 1,
          'per_page': 20,
        }),
      });
      final repository = SingerProfileRepositoryImpl(dio: dio);
      final favorites = await repository.fetchFavoriteSongs('singer_1');

      expect(favorites, hasLength(2));
      expect(favorites.first.id, 'song_1');
      expect(favorites.first.songName, 'Bohemian Rhapsody');
      expect(favorites.first.artistName, 'Queen');
      expect(favorites.last.id, 'song_2');
      expect(favorites.last.songName, 'Sweet Caroline');
      expect(favorites.last.artistName, 'Neil Diamond');
    });

    test('addFavoriteSong sends POST and accepts 201', () async {
      RequestOptions? seenRequest;
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/favorites': (options) {
          seenRequest = options;
          return _jsonResponse({
            'id': 'fav_new',
            'song_id': 'song_3',
            'title': 'Purple Rain',
            'artist': 'Prince',
            'created_at': '2026-05-12T10:00:00Z',
          }, statusCode: 201)(options);
        },
      });
      final repository = SingerProfileRepositoryImpl(dio: dio);
      await repository.addFavoriteSong(
        'singer_1',
        SongHistoryItem(
          id: 'song_3',
          songName: 'Purple Rain',
          artistName: 'Prince',
          playedAt: DateTime(2026, 5, 12),
        ),
      );

      expect(seenRequest?.method, 'POST');
      expect(seenRequest?.data, {'song_id': 'song_3'});
    });

    test('removeFavoriteSong sends DELETE and accepts 204', () async {
      RequestOptions? seenRequest;
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/favorites/song_1': (options) {
          seenRequest = options;
          return ResponseBody.fromString('', 204);
        },
      });
      final repository = SingerProfileRepositoryImpl(dio: dio);
      await repository.removeFavoriteSong('singer_1', 'song_1');

      expect(seenRequest?.method, 'DELETE');
    });
  });

  group('LeaderboardRepositoryImpl', () {
    test('parses leaderboard data wrapper with backend field aliases', () async {
      final dio = _dioWithRoutes({
        '/venues/venue_1/leaderboard': _jsonResponse({
          'data': [
            {
              'singer_id': 'singer_1',
              'stage_name': 'Alex Singer',
              'points': 1240,
              'rank': 1,
            },
            {
              'id': 'singer_2',
              'name': 'Bailey Ballad',
              'points': 930,
              'rank': 2,
            },
          ],
        }),
      });
      final repository = LeaderboardRepositoryImpl(dio: dio);

      final entries = await repository.fetchLeaderboard('venue_1', limit: 10);

      expect(entries, hasLength(2));
      expect(entries.first.singerId, 'singer_1');
      expect(entries.first.name, 'Alex Singer');
      expect(entries.first.points, 1240);
      expect(entries.last.singerId, 'singer_2');
      expect(entries.last.name, 'Bailey Ballad');
    });
  });

  group('SocialRepositoryImpl', () {
    test('follow sends POST to venue-scoped follow endpoint', () async {
      RequestOptions? seenRequest;
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/follow/singer_2': (options) {
          seenRequest = options;
          return _jsonResponse({
            'id': 'follow_1',
            'venue_id': 'venue_1',
            'follower_id': 'singer_1',
            'followee_id': 'singer_2',
            'followee_name': 'Bailey Ballad',
            'created_at': '2026-05-31T00:00:00Z',
          }, statusCode: 201)(options);
        },
      });
      final repo = SocialRepositoryImpl(dio: dio);

      await repo.follow('singer_1', 'singer_2');

      expect(seenRequest?.method, 'POST');
      expect(seenRequest?.path, '/venues/venue_1/singers/follow/singer_2');
    });

    test('unfollow sends DELETE to venue-scoped follow endpoint', () async {
      RequestOptions? seenRequest;
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/follow/singer_2': (options) {
          seenRequest = options;
          return ResponseBody.fromString('', 204);
        },
      });
      final repo = SocialRepositoryImpl(dio: dio);

      await repo.unfollow('singer_1', 'singer_2');

      expect(seenRequest?.method, 'DELETE');
      expect(seenRequest?.path, '/venues/venue_1/singers/follow/singer_2');
    });

    test('isFollowing parses true from follow status endpoint', () async {
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/follow/status/singer_2': _jsonResponse({
          'is_following': true,
          'follower_count': 14,
          'following_count': 6,
          'created_at': '2026-05-31T00:00:00Z',
        }),
      });
      final repo = SocialRepositoryImpl(dio: dio);

      final result = await repo.isFollowing('singer_1', 'singer_2');

      expect(result, isTrue);
    });

    test('isFollowing returns false on 404 or missing key', () async {
      final dio = _dioWithRoutes({
        '/venues/venue_1/singers/follow/status/singer_2': (options) {
          return ResponseBody.fromString('Not found', 404);
        },
      });
      final repo = SocialRepositoryImpl(dio: dio);

      final result = await repo.isFollowing('singer_1', 'singer_2');

      expect(result, isFalse);
    });

    test('shareToSocial sends POST to leaderboard share endpoint', () async {
      RequestOptions? seenRequest;
      final dio = _dioWithRoutes({
        '/venues/venue_1/leaderboard/share': (options) {
          seenRequest = options;
          return _jsonResponse({
            'url': 'http://share.scales/abc123',
            'expires_at': '2026-06-07T00:00:00Z',
          }, statusCode: 201)(options);
        },
      });
      final repo = SocialRepositoryImpl(dio: dio);

      await repo.shareToSocial(const SocialShare(
        singerId: 'singer_1',
        platform: 'generic',
      ));

      expect(seenRequest?.method, 'POST');
      expect(seenRequest?.path, '/venues/venue_1/leaderboard/share');
      final body = seenRequest!.data as Map<String, dynamic>;
      expect(body['content_type'], 'generic');
      expect(body['content_id'], 'singer_1');
    });
  });
}

Dio _dioWithRoutes(Map<String, _RouteHandler> routes) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://dancingdragonservices.com/api/v1',
      validateStatus: (status) => status != null && status < 500,
    ),
  )..httpClientAdapter = _FakeHttpClientAdapter(routes);
}

typedef _RouteHandler = ResponseBody Function(RequestOptions options);

_RouteHandler _jsonResponse(Object body, {int statusCode = 200}) {
  return (_) => ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

Map<String, dynamic> _songJson({required String id, required String title}) => {
      'id': id,
      'venue_id': 'venue_1',
      'catalog_id': 'cat_$id',
      'title': title,
      'artist': id == 'song_1' ? 'Queen' : 'Neil Diamond',
      'album': 'Greatest Hits',
      'genre': 'Rock',
      'duration_ms': 354000,
      'year': 1975,
      'is_available': true,
      'is_active': true,
      'created_at': '2026-05-01T00:00:00Z',
      'updated_at': '2026-05-02T00:00:00Z',
    };

class _FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, _RouteHandler> routes;

  _FakeHttpClientAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = routes[options.path];
    if (handler == null) {
      return ResponseBody.fromString('Not found: ${options.path}', 404);
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
