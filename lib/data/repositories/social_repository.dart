import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Real implementation of social repository backed by the Scales API.
class SocialRepositoryImpl implements SocialRepository {
  final Dio _dio;

  SocialRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
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

  Future<String?> _getActiveVenueId() async {
    final storage = await VenueStorage.create();
    return storage.getActiveVenueId();
  }

  @override
  Future<void> follow(String followerId, String followeeId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.post(
        '/venues/$venueId/singers/follow/$followeeId',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return;
      throw Exception('Follow failed: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  @override
  Future<void> unfollow(String followerId, String followeeId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.delete(
        '/venues/$venueId/singers/follow/$followeeId',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw Exception('Unfollow failed: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isFollowing(String followerId, String followeeId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) return false;
    try {
      final response = await _dio.get(
        '/venues/$venueId/singers/follow/status/$followeeId',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        return data?['is_following'] == true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      return false;
    }
  }

  @override
  Future<void> shareToSocial(SocialShare share) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.post(
        '/venues/$venueId/leaderboard/share',
        data: {
          'content_type': share.platform,
          'content_id': share.singerId,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return;
      throw Exception('Share failed: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }
}
