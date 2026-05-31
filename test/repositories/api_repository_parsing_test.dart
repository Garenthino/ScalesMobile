import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/data/repositories/leaderboard_repository.dart';
import 'package:scales_mobile/data/repositories/singer_profile_repository.dart';
import 'package:scales_mobile/data/repositories/song_repository.dart';
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
