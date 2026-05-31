import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Shows a bottom sheet for entering card details and confirming payment.
/// Uses Stripe's native card field widget if stripe is initialized,
/// otherwise falls back to a manual card input UI.
Future<bool?> showCardInputSheet({
  required BuildContext context,
  required String clientSecret,
  required String paymentIntentId,
  required int amountCents,
  required String description,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CardInputSheet(
      clientSecret: clientSecret,
      paymentIntentId: paymentIntentId,
      amountCents: amountCents,
      description: description,
    ),
  );

  return result;
}

class _CardInputSheet extends StatefulWidget {
  final String clientSecret;
  final String paymentIntentId;
  final int amountCents;
  final String description;

  const _CardInputSheet({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amountCents,
    required this.description,
  });

  @override
  State<_CardInputSheet> createState() => _CardInputSheetState();
}

class _CardInputSheetState extends State<_CardInputSheet> {
  bool _isProcessing = false;
  String? _error;
  bool _cardComplete = false;

  String get _formattedAmount => '\$${(widget.amountCents / 100).toStringAsFixed(2)}';

  Future<void> _pay() async {
    if (!_cardComplete) {
      setState(() => _error = 'Please complete card details');
      return;
    }
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      // Attempt to confirm the PaymentIntent with Stripe.
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: widget.clientSecret,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StripeException catch (se) {
      if (!mounted) return;
      setState(() {
        _error = se.error.localizedMessage ?? 'Payment declined. Please try again.';
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Payment failed: \$e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _simulateSuccess() async {
    // Fallback for environments where Stripe is not initialized.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final stripeAvailable = _isStripeAvailable();

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter Card Details',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Amount: $_formattedAmount',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (stripeAvailable) ...[
              CardField(
                onCardChanged: (card) {
                  setState(() {
                    _cardComplete = card?.complete ?? false;
                    if (_cardComplete) _error = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Card number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              // Stripe not available — show a styled placeholder and
              // let the user "simulate" payment for testing/demo purposes.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stripe is not configured in this build.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the button below to simulate a successful payment.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: stripeAvailable
                  ? FilledButton.icon(
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock),
                      label: Text(
                        'Pay $_formattedAmount',
                        style: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _isProcessing ? null : _pay,
                    )
                  : FilledButton.icon(
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.credit_card),
                      label: const Text(
                        'Simulate Payment',
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: _isProcessing ? null : _simulateSuccess,
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  bool _isStripeAvailable() {
    try {
      Stripe.publishableKey;
      return true;
    } catch (_) {
      return false;
    }
  }
}
