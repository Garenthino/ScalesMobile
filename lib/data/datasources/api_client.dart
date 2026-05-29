import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../services/venue_storage.dart';

/// Global Dio instance for the Scales API.
/// Automatically injects auth token from storage when present.
final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Inject auth token for protected routes
        final venueId = await _getActiveVenueId();
        if (venueId != null && !_isPublicRoute(options.path)) {
          final token = await _getTokenForVenue(venueId);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // 401 → clear token so app can re-authenticate
        if (e.response?.statusCode == 401) {
          _handle401(e.requestOptions.path);
        }
        return handler.next(e);
      },
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});

/// Public accessor.
Provider<Dio> get dioProvider => _dioProvider;

// ------------------------------------------------------------------
// Storage helpers (sync where possible, async when needed)
// ------------------------------------------------------------------

String? _activeVenueIdCache;

Future<String?> _getActiveVenueId() async {
  if (_activeVenueIdCache != null) return _activeVenueIdCache;
  final storage = await VenueStorage.create();
  _activeVenueIdCache = storage.getActiveVenueId();
  return _activeVenueIdCache;
}

Future<String?> _getTokenForVenue(String venueId) async {
  final storage = await VenueStorage.create();
  return storage.getToken(venueId);
}

bool _isPublicRoute(String? path) {
  if (path == null) return false;
  // Public discovery endpoints that don't need auth
  return path.contains('/venues/lookup') ||
         path == '/auth/register' ||
         path == '/auth/login';
}

Future<void> _handle401(String? path) async {
  // Don't clear on public routes
  if (path != null && _isPublicRoute(path)) return;
  final venueId = _activeVenueIdCache;
  if (venueId == null) return;
  final storage = await VenueStorage.create();
  await storage.clearToken(venueId);
}
