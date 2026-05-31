import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/repositories/payment_repository.dart';
import 'package:scales_mobile/domain/entities/payment.dart';
import 'package:scales_mobile/domain/repositories/payment_repository.dart';

final paymentRepoProvider = Provider<PaymentRepository>(
  (_) => PaymentRepositoryImpl(),
);

class TipParams {
  final String venueId;
  final String recipientId;
  final int amountCents;
  final String currency;
  const TipParams(this.venueId, this.recipientId, this.amountCents, this.currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TipParams &&
          runtimeType == other.runtimeType &&
          venueId == other.venueId &&
          recipientId == other.recipientId &&
          amountCents == other.amountCents &&
          currency == other.currency;
  @override
  int get hashCode => Object.hash(venueId, recipientId, amountCents, currency);
}

/// Provider for creating a tip PaymentIntent.
final createTipProvider = FutureProvider.autoDispose
    .family<PaymentIntent, TipParams>((ref, params) async {
  final repo = ref.watch(paymentRepoProvider);
  return repo.createTip(
    venueId: params.venueId,
    recipientId: params.recipientId,
    amountCents: params.amountCents,
    currency: params.currency,
  );
});

class BumpParams {
  final String venueId;
  final String requestId;
  final int amountCents;
  final String currency;
  const BumpParams(this.venueId, this.requestId, this.amountCents, this.currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BumpParams &&
          runtimeType == other.runtimeType &&
          venueId == other.venueId &&
          requestId == other.requestId &&
          amountCents == other.amountCents &&
          currency == other.currency;
  @override
  int get hashCode => Object.hash(venueId, requestId, amountCents, currency);
}

/// Provider for creating a priority-bump PaymentIntent.
final createPriorityBumpProvider = FutureProvider.autoDispose
    .family<PaymentIntent, BumpParams>((ref, params) async {
  final repo = ref.watch(paymentRepoProvider);
  return repo.createPriorityBump(
    venueId: params.venueId,
    requestId: params.requestId,
    amountCents: params.amountCents,
    currency: params.currency,
  );
});

class HistoryParams {
  final String venueId;
  final int page;
  final int perPage;
  const HistoryParams(this.venueId, this.page, this.perPage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryParams &&
          runtimeType == other.runtimeType &&
          venueId == other.venueId &&
          page == other.page &&
          perPage == other.perPage;
  @override
  int get hashCode => Object.hash(venueId, page, perPage);
}

/// Provider for paginated payment history.
final paymentHistoryProvider = FutureProvider.autoDispose
    .family<PaymentHistoryResult, HistoryParams>((ref, params) async {
  final repo = ref.watch(paymentRepoProvider);
  return repo.fetchPaymentHistory(
    venueId: params.venueId,
    page: params.page,
    perPage: params.perPage,
  );
});
