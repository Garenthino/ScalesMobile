import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/payment.dart';
import 'package:scales_mobile/domain/repositories/payment_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final Dio _dio;

  PaymentRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  Future<String?> _getActiveVenueId() async {
    final storage = await VenueStorage.create();
    return storage.getActiveVenueId();
  }

  Future<Map<String, dynamic>> _authHeaders() async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) return {};
    final storage = await VenueStorage.create();
    final token = storage.getToken(venueId);
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  Payment _mapPayment(Map<String, dynamic> data) {
    return Payment(
      id: data['id'] as String? ?? '',
      venueId: data['venue_id'] as String? ?? '',
      singerId: data['singer_id'] as String? ?? '',
      recipientId: data['recipient_id'] as String?,
      amountCents: (data['amount_cents'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'USD',
      paymentType: data['payment_type'] as String? ?? 'tip',
      status: data['status'] as String? ?? 'pending',
      createdAt: data['created_at'] as String? ?? '',
      updatedAt: data['updated_at'] as String? ?? '',
      formattedAmount: data['formatted_amount'] as String?,
    );
  }

  @override
  Future<PaymentIntent> createTip({
    required String venueId,
    required String recipientId,
    required int amountCents,
    String currency = 'USD',
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.tip(venueId),
        data: {
          'recipient_id': recipientId,
          'amount_cents': amountCents,
          'currency': currency,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return PaymentIntent(
          clientSecret: data['client_secret'] as String,
          paymentIntentId: data['payment_intent_id'] as String,
        );
      }
      throw Exception('Failed to create tip: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (e.response?.statusCode == 403) {
        throw Exception('Venue access denied.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Recipient not found.');
      }
      rethrow;
    }
  }

  @override
  Future<PaymentIntent> createPriorityBump({
    required String venueId,
    required String requestId,
    required int amountCents,
    String currency = 'USD',
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.priorityBump(venueId),
        data: {
          'request_id': requestId,
          'amount_cents': amountCents,
          'currency': currency,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return PaymentIntent(
          clientSecret: data['client_secret'] as String,
          paymentIntentId: data['payment_intent_id'] as String,
        );
      }
      throw Exception('Failed to create priority bump: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (e.response?.statusCode == 403) {
        throw Exception('Venue access denied.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Queue request not found.');
      }
      if (e.response?.statusCode == 409) {
        throw Exception('Maximum 2 priority bumps per night reached.');
      }
      rethrow;
    }
  }

  @override
  Future<PaymentHistoryResult> fetchPaymentHistory({
    required String venueId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.paymentHistory(venueId),
        queryParameters: {'page': page, 'per_page': perPage},
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final itemsRaw = data['items'] as List<dynamic>? ?? [];
        final items = itemsRaw
            .map((e) => _mapPayment(e as Map<String, dynamic>))
            .toList();
        return PaymentHistoryResult(
          items: items,
          total: (data['total'] as num?)?.toInt() ?? 0,
          page: (data['page'] as num?)?.toInt() ?? 1,
          perPage: (data['per_page'] as num?)?.toInt() ?? 20,
        );
      }
      throw Exception('Failed to fetch payment history: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }
}
