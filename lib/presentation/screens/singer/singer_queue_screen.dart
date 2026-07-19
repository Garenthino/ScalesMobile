import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/domain/entities/queue_request.dart';
import 'package:scales_mobile/presentation/providers/queue_provider.dart';
import 'package:scales_mobile/presentation/screens/payments/priority_bump_sheet.dart';

class SingerQueueScreen extends ConsumerStatefulWidget {
  const SingerQueueScreen({super.key});

  @override
  ConsumerState<SingerQueueScreen> createState() => _SingerQueueScreenState();
}

class _SingerQueueScreenState extends ConsumerState<SingerQueueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVenue = ref.watch(activeVenueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Queue'),
        bottom: activeVenue.when(
          data: (venue) {
            if (venue == null) return null;
            return TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.queue_music), text: 'Active'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            );
          },
          loading: () => null,
          error: (_, __) => null,
        ),
      ),
      body: activeVenue.when(
        data: (venue) {
          if (venue == null) return const _NoVenueState();
          return TabBarView(
            controller: _tabController,
            children: [
              _ActiveQueueTab(venueId: venue.id),
              _HistoryTab(venueId: venue.id),
            ],
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
}

// ------------------------------------------------------------------
// Active Queue Tab
// ------------------------------------------------------------------
class _ActiveQueueTab extends ConsumerWidget {
  final String venueId;
  const _ActiveQueueTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(myQueueProvider(venueId));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myQueueProvider(venueId).future),
      child: queueAsync.when(
        data: (items) {
          if (items.isEmpty) return const _EmptyActiveQueueState();
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) => _ActiveItem(
              item: items[index],
              venueId: venueId,
            ),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _QueueErrorState(
          error: error,
          onRetry: () => ref.invalidate(myQueueProvider(venueId)),
        ),
      ),
    );
  }
}

class _ActiveItem extends ConsumerWidget {
  final QueueStatusItem item;
  final String venueId;
  const _ActiveItem({required this.item, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('#${item.position}')),
        title: Text(item.songTitle),
        subtitle: Text(
          '${item.songArtist} • ${_statusLabel(item.status)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.etaSeconds != null)
              Text(_formatEta(item.etaSeconds!)),
            const SizedBox(width: 4),
            if (item.status == 'pending' || item.status == 'approved')
              IconButton(
                icon: const Icon(Icons.cancel_outlined, size: 20),
                tooltip: 'Remove request',
                onPressed: () => _confirmCancel(context, ref, venueId, item),
              ),
            IconButton(
              icon: const Icon(Icons.fast_forward, size: 20),
              tooltip: 'Priority Bump',
              onPressed: () {
                showPriorityBumpSheet(
                  context: context,
                  venueId: venueId,
                  requestId: item.requestId,
                  songTitle: item.songTitle,
                );
              },
            ),
          ],
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

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    QueueStatusItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove request?'),
        content: Text("Remove '\${item.songTitle}' from your queue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final cancel = ref.read(cancelRequestProvider(venueId));
      await cancel(item.requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove request: $e')),
        );
      }
    }
  }
}

// ------------------------------------------------------------------
// History Tab
// ------------------------------------------------------------------
class _HistoryTab extends ConsumerWidget {
  final String venueId;
  const _HistoryTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myQueueHistoryProvider(venueId));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myQueueHistoryProvider(venueId).future),
      child: historyAsync.when(
        data: (result) {
          if (result.items.isEmpty) return const _EmptyHistoryState();
          final historyItems = _aggregateHistory(result.items);
          if (historyItems.isEmpty) return const _EmptyHistoryState();
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) =>
                _HistoryItem(item: historyItems[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: historyItems.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _QueueErrorState(
          error: error,
          onRetry: () => ref.invalidate(myQueueHistoryProvider(venueId)),
        ),
      ),
    );
  }
}

class _AggregatedHistoryItem {
  final String songTitle;
  final String songArtist;
  final String? genre;
  final int timesSung;
  final DateTime? lastSung;
  final String? lastRequestId;

  _AggregatedHistoryItem({
    required this.songTitle,
    required this.songArtist,
    this.genre,
    required this.timesSung,
    this.lastSung,
    this.lastRequestId,
  });
}

List<_AggregatedHistoryItem> _aggregateHistory(List<QueueHistoryItem> items) {
  final map = <String, _AggregatedHistoryItem>{};
  for (final item in items) {
    // Rejected/skipped requests do not belong in song history.
    if (item.status == 'rejected' || item.status == 'skipped') continue;
    final key = '${item.songArtist.toLowerCase()}::${item.songTitle.toLowerCase()}';
    final existing = map[key];
    final itemDate = _parseTimestamp(item.playedAt ?? item.requestedAt);
    if (existing == null ||
        (itemDate != null &&
            (existing.lastSung == null || itemDate.isAfter(existing.lastSung!)))) {
      map[key] = _AggregatedHistoryItem(
        songTitle: item.songTitle,
        songArtist: item.songArtist,
        genre: item.genre,
        timesSung: (existing?.timesSung ?? 0) + 1,
        lastSung: itemDate ?? existing?.lastSung,
        lastRequestId: item.requestId,
      );
    } else {
      map[key] = _AggregatedHistoryItem(
        songTitle: existing.songTitle,
        songArtist: existing.songArtist,
        genre: existing.genre,
        timesSung: existing.timesSung + 1,
        lastSung: existing.lastSung,
        lastRequestId: existing.lastRequestId,
      );
    }
  }
  final list = map.values.toList();
  list.sort((a, b) => (b.lastSung ?? DateTime(1970)).compareTo(a.lastSung ?? DateTime(1970)));
  return list;
}

DateTime? _parseTimestamp(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

class _HistoryItem extends StatelessWidget {
  final _AggregatedHistoryItem item;
  const _HistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.music_note),
        title: Text(item.songTitle),
        subtitle: Text(
          '${item.songArtist}${item.genre != null && item.genre!.isNotEmpty ? ' • ${item.genre}' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.timesSung}x sung',
              style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (item.lastSung != null)
              Text(
                _formatTimestamp(item.lastSung!.toIso8601String()),
                style: theme.textTheme.labelSmall,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ------------------------------------------------------------------
// Shared states
// ------------------------------------------------------------------
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

class _EmptyActiveQueueState extends StatelessWidget {
  const _EmptyActiveQueueState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.queue_music, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No active song requests yet.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Browse songs and add one to the queue!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No history yet.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your past performances will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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

class _QueueErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _QueueErrorState({required this.error, required this.onRetry});

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
              'Could not load queue',
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
