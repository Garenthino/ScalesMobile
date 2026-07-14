import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';

/// DTO for global account auth responses.
class AccountAuthResult {
  final String accessToken;
  final String refreshToken;
  final String accountId;
  final int expiresIn;

  const AccountAuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.accountId,
    required this.expiresIn,
  });

  factory AccountAuthResult.fromJson(Map<String, dynamic> json) {
    return AccountAuthResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accountId: json['account_id'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// DTO for venue-scoped token returned by /venues/{id}/join.
class VenueAuthResult {
  final String accessToken;
  final String refreshToken;
  final String singerId;
  final String venueId;
  final int expiresIn;

  const VenueAuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.singerId,
    required this.venueId,
    required this.expiresIn,
  });

  factory VenueAuthResult.fromJson(Map<String, dynamic> json) {
    return VenueAuthResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      singerId: json['singer_id'] as String? ?? json['account_id'] as String,
      venueId: '', // populated by caller
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Repository for global mobile-account auth.
class AccountAuthRepository {
  final Dio _dio;

  AccountAuthRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Register a new global account.
  Future<AccountAuthResult> register({
    required String email,
    required String password,
    required String stageName,
    String? firstName,
    String? lastName,
    String? pronouns,
    String? phone,
    String? bio,
  }) async {
    final response = await _dio.post(
      '/accounts/register',
      data: {
        'email': email,
        'password': password,
        'stage_name': stageName,
        'first_name': firstName,
        'last_name': lastName,
        'pronouns': pronouns,
        'phone': phone,
        'bio': bio,
      },
    );
    if (response.statusCode == 201) {
      return AccountAuthResult.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Account registration failed: ${response.statusCode}');
  }

  /// Log in to global account.
  Future<AccountAuthResult?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/accounts/login',
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        return AccountAuthResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Refresh global account access token.
  Future<AccountAuthResult?> refresh(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/accounts/refresh',
        data: {'refresh_token': refreshToken},
      );
      if (response.statusCode == 200) {
        return AccountAuthResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Validate global account token.
  Future<String?> validateToken(String token) async {
    try {
      final response = await _dio.get(
        '/accounts/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['id'] as String?;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Join a venue with the global account, creating a per-venue singer row.
  Future<VenueAuthResult> joinVenue({required String venueId, required String accountToken}) async {
    final response = await _dio.post(
      '/venues/$venueId/join',
      options: Options(headers: {'Authorization': 'Bearer $accountToken'}),
    );
    if (response.statusCode == 200) {
      final result = VenueAuthResult.fromJson(response.data as Map<String, dynamic>);
      return VenueAuthResult(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        singerId: result.singerId,
        venueId: venueId,
        expiresIn: result.expiresIn,
      );
    }
    throw Exception('Venue join failed: ${response.statusCode}');
  }
}

/// Riverpod provider for the global account auth repository.
final accountAuthRepositoryProvider = Provider<AccountAuthRepository>((ref) => AccountAuthRepository());

/// Legacy per-venue auth repository kept for compatibility with existing KJ/desktop flows.
class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Register a new singer account directly in a venue (legacy path).
  Future<String> register({
    required String venueId,
    required String stageName,
    required String email,
    required String password,
    String? realName,
    String? pronouns,
    String? phone,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'venue_id': venueId,
        'stage_name': stageName,
        'email': email,
        'password': password,
        'real_name': realName,
        'pronouns': pronouns,
        'phone': phone,
      },
    );
    if (response.statusCode == 201) {
      return response.data['id'] as String;
    }
    throw Exception('Registration failed: ${response.statusCode}');
  }

  /// Log in with email/password for a venue-scoped token.
  Future<AccountAuthResult?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/accounts/login',
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        return AccountAuthResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Refresh using a global account refresh token.
  Future<AccountAuthResult?> refresh(String refreshToken) async {
    return AccountAuthRepository(dio: _dio).refresh(refreshToken);
  }

  /// Validate a token.
  Future<String?> validateToken(String token) async {
    return AccountAuthRepository(dio: _dio).validateToken(token);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
