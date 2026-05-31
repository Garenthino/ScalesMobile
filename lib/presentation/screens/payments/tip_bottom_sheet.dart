import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/payment_provider.dart';
import 'card_input_sheet.dart';

/// Shows a bottom sheet for sending a tip to a singer.
/// Returns true if a PaymentIntent was successfully created and confirmed.
Future<bool> showTipSheet({
  required BuildContext context,
  required String venueId,
  required String recipientId,
  required String recipientName,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TipSheet(
      venueId: venueId,
      recipientId: recipientId,
      recipientName: recipientName,
    ),
  );
  return result ?? false;
}

class _TipSheet extends ConsumerStatefulWidget {
  final String venueId;
  final String recipientId;
  final String recipientName;

  const _TipSheet({
    required this.venueId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  ConsumerState<_TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends ConsumerState<_TipSheet> {
  int _selectedCents = 0;
  bool _customMode = false;
  final _customController = TextEditingController();
  bool _isProcessing = false;

  static const List<int> _presets = [
    PaymentPresets.tip1,
    PaymentPresets.tip2,
    PaymentPresets.tip3,
    PaymentPresets.tip4,
  ];

  String _formatCents(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  int get _amountCents {
    if (_customMode) {
      final val = double.tryParse(_customController.text);
      if (val == null || val <= 0) return 0;
      return (val * 100).round();
    }
    return _selectedCents;
  }

  Future<void> _confirm() async {
    final amount = _amountCents;
    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum tip is \$1.00')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final params = TipParams(
        widget.venueId,
        widget.recipientId,
        amount,
        'USD',
      );
      final intent = await ref.read(createTipProvider(params).future);

      if (!mounted) return;

      final confirmed = await showCardInputSheet(
        context: context,
        clientSecret: intent.clientSecret,
        paymentIntentId: intent.paymentIntentId,
        amountCents: amount,
        description: 'Tip for ${widget.recipientName}',
      );

      if (!mounted) return;
      if (confirmed == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send tip. Please try again.')),
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
            Text(
              'Send a Tip',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'to ${widget.recipientName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ..._presets.map((cents) {
                  final selected = !_customMode && _selectedCents == cents;
                  return ChoiceChip(
                    label: Text(_formatCents(cents)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _customMode = false;
                        _selectedCents = cents;
                      });
                    },
                  );
                }),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _customMode,
                  onSelected: (_) {
                    setState(() {
                      _customMode = true;
                      _selectedCents = 0;
                    });
                  },
                ),
              ],
            ),
            if (_customMode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  labelText: 'Amount',
                  hintText: '5.00',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isProcessing ? null : _confirm,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Tip ${_formatCents(_amountCents)}',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
