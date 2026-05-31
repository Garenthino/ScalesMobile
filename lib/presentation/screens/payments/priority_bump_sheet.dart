import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/payment_provider.dart';
import 'card_input_sheet.dart';

/// Shows a bottom sheet for purchasing a queue priority bump.
/// Returns true if a PaymentIntent was successfully created and confirmed.
Future<bool> showPriorityBumpSheet({
  required BuildContext context,
  required String venueId,
  required String requestId,
  required String songTitle,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PriorityBumpSheet(
      venueId: venueId,
      requestId: requestId,
      songTitle: songTitle,
    ),
  );
  return result ?? false;
}

class _PriorityBumpSheet extends ConsumerStatefulWidget {
  final String venueId;
  final String requestId;
  final String songTitle;

  const _PriorityBumpSheet({
    required this.venueId,
    required this.requestId,
    required this.songTitle,
  });

  @override
  ConsumerState<_PriorityBumpSheet> createState() => _PriorityBumpSheetState();
}

class _PriorityBumpSheetState extends ConsumerState<_PriorityBumpSheet> {
  bool _isProcessing = false;

  String get _formattedCost =>
      '\$${(PaymentPresets.priorityBump / 100).toStringAsFixed(2)}';

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);
    try {
      final params = BumpParams(
        widget.venueId,
        widget.requestId,
        PaymentPresets.priorityBump,
        'USD',
      );
      final intent = await ref.read(createPriorityBumpProvider(params).future);

      if (!mounted) return;

      final confirmed = await showCardInputSheet(
        context: context,
        clientSecret: intent.clientSecret,
        paymentIntentId: intent.paymentIntentId,
        amountCents: PaymentPresets.priorityBump,
        description: 'Priority bump for "${widget.songTitle}"',
      );

      if (!mounted) return;
      if (confirmed == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isProcessing = false);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            Row(
              children: [
                Icon(Icons.fast_forward, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Priority Bump',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Move "${widget.songTitle}" up the queue by up to 2 positions.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cost', style: theme.textTheme.bodyLarge),
                        Text(
                          _formattedCost,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Positions gained', style: theme.textTheme.bodyLarge),
                        Text(
                          'Up to 2',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Limit: 2 priority bumps per night.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  'Pay $_formattedCost',
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: _isProcessing ? null : _confirm,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
