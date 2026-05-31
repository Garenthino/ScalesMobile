import 'package:scales_mobile/domain/entities/payment.dart';

/// Operations for tips, priority bumps, and payment history.
abstract class PaymentRepository {
  /// Create a Stripe PaymentIntent for tipping a singer.
  Future<PaymentIntent> createTip({
    required String venueId,
    required String recipientId,
    required int amountCents,
    String currency,
  });

  /// Create a Stripe PaymentIntent for a queue priority bump.
  Future<PaymentIntent> createPriorityBump({
    required String venueId,
    required String requestId,
    required int amountCents,
    String currency,
  });

  /// Fetch the current singer's payment history at this venue.
  Future<PaymentHistoryResult> fetchPaymentHistory({
    required String venueId,
    int page,
    int perPage,
  });
}
