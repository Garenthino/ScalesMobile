import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/social_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  final String venueId;
  const LeaderboardScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider(venueId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Venue ID: $venueId',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: leaderboardAsync.when(
        data: (entries) => _LeaderboardView(entries: entries),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _LeaderboardView extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _LeaderboardView({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No leaderboard data yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: _RankBadge(rank: entry.rank),
            title: Text(entry.name),
            subtitle: Text('${entry.points} pts'),
            trailing: _FollowButton(singerId: entry.singerId, name: entry.name),
          ),
        );
      },
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  Color _rankColor() {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => Colors.transparent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _rankColor();
    final isTop3 = rank <= 3;
    return CircleAvatar(
      radius: isTop3 ? 22 : 18,
      backgroundColor: isTop3 ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isTop3 ? Colors.black : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String singerId;
  final String name;
  const _FollowButton({required this.singerId, required this.name});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(_following ? Icons.person_remove : Icons.person_add),
      label: Text(_following ? 'Unfollow' : 'Follow'),
      onPressed: () => setState(() => _following = !_following),
    );
  }
}
