import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';

/// Lightweight DTO for venue discovery (no auth required).
class VenueCompact {
  final String id;
  final String name;
  final String slug;
  final String venueCode;
  final String timezone;
  final bool isActive;

  const VenueCompact({
    required this.id,
    required this.name,
    required this.slug,
    required this.venueCode,
    required this.timezone,
    required this.isActive,
  });

  factory VenueCompact.fromJson(Map<String, dynamic> json) {
    return VenueCompact(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      venueCode: json['venue_code'] as String,
      timezone: json['timezone'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}

/// Extended venue model for detail screen.
class VenueDetail {
  final String id;
  final String name;
  final String slug;
  final String venueCode;
  final String timezone;
  final bool isActive;
  final String? address;
  final String? phone;
  final String? description;
  final String? logoUrl;
  final int? capacity;

  const VenueDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.venueCode,
    required this.timezone,
    required this.isActive,
    this.address,
    this.phone,
    this.description,
    this.logoUrl,
    this.capacity,
  });

  factory VenueDetail.fromJson(Map<String, dynamic> json) {
    return VenueDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      venueCode: json['venue_code'] as String,
      timezone: json['timezone'] as String,
      isActive: json['is_active'] as bool,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
    );
  }
}

/// Repository for public venue discovery (no authentication).
class VenueRepository {
  final Dio _dio;

  VenueRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Look up a venue by its short code (e.g. "GOLDEN").
  /// Returns null if the code is invalid or the venue is inactive.
  Future<VenueCompact?> lookupByCode(String code) async {
    try {
      final response = await _dio.get(
        '/venues/lookup',
        queryParameters: {'code': code.toUpperCase()},
      );
      if (response.statusCode == 200) {
        return VenueCompact.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Fetch full venue details by ID.
  Future<VenueDetail?> fetchVenue(String id) async {
    try {
      final response = await _dio.get('/venues/$id');
      if (response.statusCode == 200) {
        return VenueDetail.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
