import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../services/venue_storage.dart';
import '../../domain/repositories/singer_repository.dart';
import '../../domain/entities/singer_profile.dart';

/// Real check-in repository backed by the Scales REST API.
class CheckInRepositoryImpl implements CheckInRepository {
  final Dio _dio;

  CheckInRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  @override
  Future<CheckInResult> checkIn(String venueId, String singerId, {String? code}) async {
    try {
      // The backend checkin endpoint is /venues/{venue_id}/singers/checkin
      final response = await _dio.post(
        '/venues/$venueId/singers/checkin',
        data: {
          'nickname': null,
          'table_number': null,
          'party_size': null,
          'phone': null,
          'marketing_consent': false,
        },
        options: Options(headers: await _authHeaders(venueId)),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return CheckInResult(
          success: true,
          venueId: venueId,
          venueName: data['stage_name'] as String? ?? 'Venue',
          message: 'Checked in successfully!',
        );
      }
      return CheckInResult(
        success: false,
        message: 'Check-in failed: ${response.statusCode}',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const CheckInResult(
          success: false,
          message: 'Session expired. Please sign in again.',
        );
      }
      return CheckInResult(
        success: false,
        message: 'Network error: ${e.message}',
      );
    }
  }

  @override
  Future<CheckInResult> getCurrentCheckIn(String singerId) async {
    // No dedicated endpoint for this yet; assume not checked in
    return const CheckInResult(
      success: false,
      message: 'Not checked into any venue',
    );
  }

  Future<Map<String, dynamic>> _authHeaders(String venueId) async {
    final storage = await VenueStorage.create();
    final token = storage.getToken(venueId);
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }
}

/// Riverpod provider for the real check-in repository.
final checkInRepoProvider = Provider<CheckInRepository>((_) => CheckInRepositoryImpl());
