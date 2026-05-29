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
        final storage = await VenueStorage.create();
        final venueName = _findVenueName(storage, venueId) ?? 'Venue';
        await storage.setLastCheckIn(venueId: venueId, venueName: venueName);
        return CheckInResult(
          success: true,
          venueId: venueId,
          venueName: venueName,
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
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();

    // Query backend if we have an active venue with a token
    if (venueId != null && (storage.getToken(venueId)?.isNotEmpty ?? false)) {
      try {
        final response = await _dio.get(
          '/venues/$venueId/singers/profile',
          options: Options(headers: await _authHeaders(venueId)),
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final lastSeen = data['last_seen'] as String?;
          if (lastSeen != null && lastSeen.isNotEmpty) {
            final lastSeenTime = DateTime.tryParse(lastSeen)?.toUtc();
            final now = DateTime.now().toUtc();
            final isRecent = lastSeenTime != null && now.difference(lastSeenTime).inHours < 24;

            if (isRecent) {
              final venueName = _findVenueName(storage, venueId) ?? 'Venue';
              await storage.setLastCheckIn(venueId: venueId, venueName: venueName);
              return CheckInResult(
                success: true,
                venueId: venueId,
                venueName: venueName,
                message: 'Checked in successfully!',
              );
            }
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          return const CheckInResult(
            success: false,
            message: 'Session expired. Please sign in again.',
          );
        }
        // Fall through to cache on other network errors
      }
    }

    // Fallback to local cache
    final cached = storage.getLastCheckIn();
    if (cached != null) {
      final cachedVenueId = cached['venue_id'] as String?;
      final cachedVenueName = cached['venue_name'] as String?;
      final checkedInAt = DateTime.tryParse(cached['checked_in_at'] as String? ?? '')?.toUtc();
      final now = DateTime.now().toUtc();
      if (checkedInAt != null && now.difference(checkedInAt).inHours < 24) {
        return CheckInResult(
          success: true,
          venueId: cachedVenueId,
          venueName: cachedVenueName,
          message: 'Checked in (cached)',
        );
      }
      await storage.clearLastCheckIn();
    }

    return const CheckInResult(
      success: false,
      message: 'Not checked into any venue',
    );
  }

  String? _findVenueName(VenueStorage storage, String venueId) {
    for (final v in storage.getVenues()) {
      if (v.id == venueId) return v.name;
    }
    return null;
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
