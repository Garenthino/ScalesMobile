import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

/// Real implementation of leaderboard repository backed by the Scales API.
class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final Dio _dio;

  LeaderboardRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard(String venueId, {int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/venues/$venueId/leaderboard',
        queryParameters: {'limit': limit},
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
        return rawList.map((e) => _mapEntry(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  LeaderboardEntry _mapEntry(Map<String, dynamic> data) {
    return LeaderboardEntry(
      singerId: data['singer_id'] as String? ?? data['id']?.toString() ?? '',
      name: data['stage_name'] as String? ?? data['name'] as String? ?? 'Unknown',
      avatarUrl: data['avatar_url'] as String?,
      points: (data['points'] as num?)?.toInt() ?? 0,
      rank: (data['rank'] as num?)?.toInt() ?? 0,
    );
  }
}
