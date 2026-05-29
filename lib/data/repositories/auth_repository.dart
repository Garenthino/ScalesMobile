import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';

/// DTO for auth login response.
class AuthResult {
  final String accessToken;
  final String refreshToken;
  final String singerId;
  final String venueId;
  final int expiresIn;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.singerId,
    required this.venueId,
    required this.expiresIn,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      singerId: json['singer_id'] as String,
      venueId: json['venue_id'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Real auth repository backed by the Scales REST API.
class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Register a new singer account.
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

  /// Log in with email/password.
  /// Returns null if credentials are invalid.
  Future<AuthResult?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        return AuthResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Refresh the access token using a refresh token.
  Future<AuthResult?> refresh(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      if (response.statusCode == 200) {
        return AuthResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Verify a token by calling /auth/me.
  /// Returns the singer ID if valid, null otherwise.
  Future<String?> validateToken(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me',
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
}

/// Riverpod provider for the auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
