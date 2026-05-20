import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global Dio instance for the Scales API.
/// Inject this via Riverpod so tests can swap in a mock.

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio()
    ..options.baseUrl = 'https://api.scales.dev/v1'
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 15);

  // Attach interceptors if needed (auth, logging)
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token from storage here
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Global error handling
        return handler.next(e);
      },
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});

/// Public accessor—keeps consumer code clean.
Provider<Dio> get dioProvider => _dioProvider;
