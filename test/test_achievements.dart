import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scales_mobile/data/repositories/achievement_repository.dart';
import 'package:scales_mobile/domain/entities/achievement.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'scales_active_venue_id': 'venue_1',
      'scales_auth_venue_1': 'test-access-token',
    });
  });

  test('AchievementRepositoryImpl parses achievements list', () async {
    final dio = _dioWithRoutes({
      '/venues/venue_1/singers/me/achievements': (options) => _jsonResponse([
        {
          'achievement_key': 'first_song',
          'name': 'First Song',
          'description': 'Perform your first song',
          'icon': 'mic',
          'progress': 1,
          'target': 1,
          'unlocked_at': '2026-05-30T12:00:00Z',
          'unlocked': true,
        },
        {
          'achievement_key': 'iron_lungs',
          'name': 'Iron Lungs',
          'description': 'Perform 50 songs',
          'icon': 'music',
          'progress': 23,
          'target': 50,
          'unlocked_at': null,
          'unlocked': false,
        },
      ]),
    });
    final repository = AchievementRepositoryImpl(dio: dio);

    final achievements = await repository.fetchMyAchievements();

    expect(achievements, hasLength(2));
    expect(achievements.first.key, 'first_song');
    expect(achievements.first.unlocked, isTrue);
    expect(achievements.first.progressRatio, 1.0);
    expect(achievements[1].key, 'iron_lungs');
    expect(achievements[1].unlocked, isFalse);
    expect(achievements[1].progressRatio, 23 / 50);
  });

  test('AchievementRepositoryImpl handles empty list', () async {
    final dio = _dioWithRoutes({
      '/venues/venue_1/singers/me/achievements': (options) => _jsonResponse([]),
    });
    final repository = AchievementRepositoryImpl(dio: dio);

    final achievements = await repository.fetchMyAchievements();

    expect(achievements, isEmpty);
  });

  test('AchievementRepositoryImpl handles data wrapper', () async {
    final dio = _dioWithRoutes({
      '/venues/venue_1/singers/me/achievements': (options) => _jsonResponse({
        'data': [
          {
            'achievement_key': 'regular',
            'name': 'Regular',
            'description': 'Check in 10 times',
            'progress': 8,
            'target': 10,
            'unlocked_at': null,
            'unlocked': false,
          },
        ],
      }),
    });
    final repository = AchievementRepositoryImpl(dio: dio);

    final achievements = await repository.fetchMyAchievements();

    expect(achievements.single.key, 'regular');
    expect(achievements.single.progress, 8);
  });
}

typedef _RouteHandler = ResponseBody Function(RequestOptions options);

ResponseBody _jsonResponse(dynamic data) {
  final body = jsonEncode(data);
  return ResponseBody.fromString(body, 200, headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  });
}

Dio _dioWithRoutes(Map<String, _RouteHandler> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'https://dancingdragonservices.com/api/v1'));
  dio.httpClientAdapter = _FakeHttpClientAdapter(routes);
  return dio;
}

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
