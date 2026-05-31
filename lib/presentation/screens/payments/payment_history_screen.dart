import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/payment.dart';
import '../../providers/queue_provider.dart';
import '../../providers/payment_provider.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  int _page = 1;
  static const int _perPage = 20;

  Future<void> _onRefresh() async {
    final venueAsync = ref.read(activeVenueProvider);
    venueAsync.whenData((venue) {
      if (venue != null) {
        ref.invalidate(paymentHistoryProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(activeVenueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: venueAsync.when(
        data: (venue) {
          if (venue == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Select a venue to view payment history.'),
              ),
            );
          }
          final params = HistoryParams(venue.id, _page, _perPage);
          final historyAsync = ref.watch(paymentHistoryProvider(params));

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: historyAsync.when(
              data: (result) {
                if (result.items.isEmpty) {
                  return _EmptyState(onRefresh: _onRefresh);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: result.items.length + (result.total > result.items.length ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == result.items.length) {
                      return _LoadMoreButton(
                        onTap: () => setState(() => _page++),
                      );
                    }
                    return _PaymentCard(payment: result.items[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                error: error,
                onRetry: () => ref.invalidate(paymentHistoryProvider),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading venue')),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = switch (payment.status) {
      'succeeded' => Colors.green,
      'failed' => colorScheme.error,
      'canceled' => Colors.grey,
      _ => Colors.orange,
    };

    final icon = switch (payment.paymentType) {
      'tip' => Icons.volunteer_activism,
      'priority_bump' => Icons.fast_forward,
      _ => Icons.payment,
    };

    final title = switch (payment.paymentType) {
      'tip' => 'Tip',
      'priority_bump' => 'Priority Bump',
      _ => 'Payment',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(icon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payment.displayAmount,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(payment.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(
                payment.status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: statusColor.withValues(alpha: 0.1),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '\$month/\$day  \$hour:\$minute';
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No payments yet.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tips and priority bumps will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load payments',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: onTap,
        child: const Text('Load more'),
      ),
    );
  }
}
