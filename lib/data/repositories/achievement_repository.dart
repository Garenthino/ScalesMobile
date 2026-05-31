import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/achievement.dart';
import 'package:scales_mobile/domain/repositories/achievement_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Real implementation of achievements repository backed by the Scales API.
class AchievementRepositoryImpl implements AchievementRepository {
  final Dio _dio;

  AchievementRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  Future<Map<String, dynamic>> _authHeaders() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) return {};
    final token = storage.getToken(venueId);
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  @override
  Future<List<Achievement>> fetchMyAchievements() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.get(
        '/venues/$venueId/singers/me/achievements',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final List<dynamic> rawList;
        final data = response.data;
        if (data is List<dynamic>) {
          rawList = data;
        } else if (data is Map<String, dynamic>) {
          rawList = data['data'] as List<dynamic>? ?? [];
        } else {
          rawList = [];
        }
        // cache raw JSON for offline fallback
        await storage.saveAchievements(
          venueId,
          rawList.map((e) => e as Map<String, dynamic>).toList(),
        );
        return rawList.map((e) => _mapAchievement(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      // offline fallback
      if (_isOfflineError(e)) {
        final cached = storage.getAchievements(venueId);
        if (cached != null) {
          return cached.map(_mapAchievement).toList();
        }
      }
      rethrow;
    }
  }

  bool _isOfflineError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return true;
      default:
        return false;
    }
  }

  Achievement _mapAchievement(Map<String, dynamic> data) {
    return Achievement(
      key: data['achievement_key'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown',
      description: data['description'] as String? ?? '',
      icon: data['icon'] as String?,
      progress: (data['progress'] as num?)?.toInt() ?? 0,
      target: (data['target'] as num?)?.toInt() ?? 1,
      unlockedAt: data['unlocked_at'] as String?,
      unlocked: data['unlocked'] as bool? ?? false,
    );
  }
}
