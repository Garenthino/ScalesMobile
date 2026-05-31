import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/presentation/providers/queue_provider.dart';

class SingerQueueScreen extends ConsumerWidget {
  const SingerQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeVenue = ref.watch(activeVenueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Queue')),
      body: activeVenue.when(
        data: (venue) {
          if (venue == null) return const _NoVenueState();
          final queueState = ref.watch(myQueueStatusProvider(venue.id));
          return queueState.when(
            data: (items) {
              if (items.isEmpty) return const _EmptyQueueState();
              return RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(myQueueStatusProvider(venue.id).future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('#${item.position}')),
                        title: Text(item.songTitle),
                        subtitle: Text(
                          '${item.songArtist} • ${_statusLabel(item.status)}',
                        ),
                        trailing: item.etaSeconds == null
                            ? null
                            : Text(_formatEta(item.etaSeconds!)),
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: items.length,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _QueueErrorState(
              error: error,
              onRetry: () => ref.invalidate(myQueueStatusProvider(venue.id)),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _QueueErrorState(
          error: error,
          onRetry: () => ref.invalidate(activeVenueProvider),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => 'Waiting for KJ approval',
      'approved' => 'Approved',
      'now_playing' => 'Now playing',
      'completed' => 'Completed',
      'skipped' => 'Skipped',
      _ => status,
    };
  }

  String _formatEta(int seconds) {
    if (seconds <= 0) return 'Soon';
    final minutes = (seconds / 60).ceil();
    return '~${minutes}m';
  }
}

class _NoVenueState extends StatelessWidget {
  const _NoVenueState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Select a venue before viewing your queue.'),
      ),
    );
  }
}

class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No active song requests yet.'),
      ),
    );
  }
}

class _QueueErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _QueueErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load queue',
              style: Theme.of(context).textTheme.titleLarge,
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
