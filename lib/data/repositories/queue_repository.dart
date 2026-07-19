import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/data/models/queue_request_model.dart';
import 'package:scales_mobile/domain/entities/queue_request.dart';
import 'package:scales_mobile/domain/repositories/queue_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Real implementation of singer-facing queue operations backed by the Scales API.
class QueueRepositoryImpl implements QueueRepository {
  final Dio _dio;

  QueueRepositoryImpl({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiEndpoints.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  @override
  Future<QueueJoinResult> joinQueue({
    required String venueId,
    required String songId,
    String? notes,
  }) async {
    await _requireAuthToken(venueId);
    try {
      final response = await _dio.post(
        ApiEndpoints.queueJoin(venueId),
        data: QueueJoinRequestModel(songId: songId, notes: notes).toJson(),
      );

      if (response.statusCode == StatusCodes.created &&
          response.data is Map<String, dynamic>) {
        return QueueJoinResultModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw Exception(
        _errorMessage(response, fallback: 'Could not request song.'),
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  @override
  Future<List<QueueStatusItem>> fetchMyQueueStatus({
    required String venueId,
  }) async {
    await _requireAuthToken(venueId);
    try {
      final response = await _dio.get(ApiEndpoints.myQueue(venueId));
      if (response.statusCode == StatusCodes.ok &&
          response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawItems = data['items'];
        if (rawItems is List<dynamic>) {
          return rawItems
              .whereType<Map<String, dynamic>>()
              .map(QueueStatusItemModel.fromJson)
              .toList(growable: false);
        }
        return const [];
      }
      throw Exception(
        _errorMessage(response, fallback: 'Could not load your queue.'),
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  @override
  Future<QueueHistoryResult> fetchMyQueueHistory({
    required String venueId,
    int page = 1,
    int perPage = 20,
  }) async {
    await _requireAuthToken(venueId);
    try {
      final response = await _dio.get(
        ApiEndpoints.myQueueHistory(venueId),
        queryParameters: {'page': page, 'per_page': perPage},
      );
      if (response.statusCode == StatusCodes.ok &&
          response.data is Map<String, dynamic>) {
        return QueueHistoryResultModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw Exception(
        _errorMessage(response, fallback: 'Could not load queue history.'),
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  @override
  Future<void> cancelRequest({
    required String venueId,
    required String requestId,
  }) async {
    await _requireAuthToken(venueId);
    try {
      final response = await _dio.delete(
        ApiEndpoints.myQueueCancel(venueId, requestId),
      );
      if (response.statusCode == StatusCodes.ok ||
          response.statusCode == StatusCodes.noContent) {
        return;
      }
      throw Exception(
        _errorMessage(response, fallback: 'Could not cancel request.'),
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  @override
  Future<int> leaveQueue({required String venueId, String? requestId}) async {
    await _requireAuthToken(venueId);
    try {
      final response = await _dio.delete(
        ApiEndpoints.queueLeave(venueId),
        queryParameters: {
          if (requestId != null && requestId.isNotEmpty)
            'request_id': requestId,
        },
      );
      if (response.statusCode == StatusCodes.ok &&
          response.data is Map<String, dynamic>) {
        return _intValue((response.data as Map<String, dynamic>)['removed']);
      }
      throw Exception(
        _errorMessage(response, fallback: 'Could not leave queue.'),
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  @override
  Future<PublicQueue> fetchVenueQueue({required String venueId}) async {
    try {
      final response = await _dio.get(ApiEndpoints.queueVenue(venueId));
      if (response.statusCode == StatusCodes.ok &&
          response.data is Map<String, dynamic>) {
        return PublicQueueModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception(
        _errorMessage(response, fallback: 'Could not load venue queue.'),
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e));
    }
  }

  Future<void> _requireAuthToken(String venueId) async {
    final storage = await VenueStorage.create();
    final token = storage.getToken(venueId);
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in before requesting a song.');
    }
  }

  String _errorMessage(Response<dynamic> response, {required String fallback}) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List<dynamic> && detail.isNotEmpty) {
        return detail.first.toString();
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (response.statusCode == StatusCodes.unauthorized) {
      return 'Session expired. Please sign in again.';
    }
    return '$fallback (${response.statusCode})';
  }

  String _dioErrorMessage(DioException e) {
    if (e.response != null) {
      return _errorMessage(e.response!, fallback: 'Queue request failed.');
    }
    return 'Network error: ${e.message ?? 'Please check your connection.'}';
  }
}

int _intValue(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
