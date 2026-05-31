/// Represents a single payment record.
class Payment {
  final String id;
  final String venueId;
  final String singerId;
  final String? recipientId;
  final int amountCents;
  final String currency;
  final String paymentType; // 'tip' | 'priority_bump'
  final String status; // 'pending' | 'succeeded' | 'failed' | 'canceled'
  final String createdAt;
  final String updatedAt;
  final String? formattedAmount;

  const Payment({
    required this.id,
    required this.venueId,
    required this.singerId,
    this.recipientId,
    required this.amountCents,
    this.currency = 'USD',
    required this.paymentType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.formattedAmount,
  });

  String get displayAmount {
    return formattedAmount ?? '\$${(amountCents / 100).toStringAsFixed(2)}';
  }
}

/// Result returned when creating a Stripe PaymentIntent.
class PaymentIntent {
  final String clientSecret;
  final String paymentIntentId;

  const PaymentIntent({
    required this.clientSecret,
    required this.paymentIntentId,
  });
}

/// Paginated payment history result.
class PaymentHistoryResult {
  final List<Payment> items;
  final int total;
  final int page;
  final int perPage;

  const PaymentHistoryResult({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });
}
