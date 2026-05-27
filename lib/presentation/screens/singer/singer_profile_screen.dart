import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/auth_provider.dart';
import 'package:scales_mobile/presentation/providers/profile_provider.dart';

class SingerProfileScreen extends ConsumerWidget {
  const SingerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = switch (authState) {
      Authenticated(:final userId) => userId,
      _ => 'demo_user',
    };

    final profileAsync = ref.watch(singerProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () => context.push(RoutePaths.singerProfileEdit, extra: userId),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _ProfileBody(profile: profile, userId: userId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final SingerProfile profile;
  final String userId;

  const _ProfileBody({required this.profile, required this.userId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 56,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? const Icon(Icons.person, size: 56)
                : null,
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            profile.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (profile.bio != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                profile.bio!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          // Stats row
          _StatsRow(profile: profile),
          const SizedBox(height: 24),
          // Loyalty tier
          _TierCard(tier: profile.tier),
          const SizedBox(height: 24),
          // QR code for quick check-in
          _CheckInQR(userId: userId),
          const SizedBox(height: 24),
          // Song history
          _SectionTitle(title: 'Song History (${profile.songHistory.length})'),
          _SongList(songs: profile.songHistory),
          const SizedBox(height: 24),
          // Favorite songs
          _SectionTitle(title: 'Favorite Songs (${profile.favoriteSongs.length})'),
          _SongList(songs: profile.favoriteSongs),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final SingerProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat(label: 'Performances', value: '${profile.performancesCount}'),
      _Stat(label: 'Followers', value: '${profile.followersCount}'),
      _Stat(label: 'Following', value: '${profile.followingCount}'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: stats
          .map(
            (s) => Column(
              children: [
                Text(s.value,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(s.label,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
}

class _TierCard extends StatelessWidget {
  final LoyaltyTier tier;
  const _TierCard({required this.tier});

  Color _parseColor(String hex) {
    final c = hex.replaceAll('#', '');
    return Color(int.parse('FF$c', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: _parseColor(tier.color)),
                const SizedBox(width: 8),
                Text('${tier.name} Tier',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: tier.points / (tier.points + tier.pointsToNextTier),
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                _parseColor(tier.color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${tier.points} pts  /  ${tier.points + tier.pointsToNextTier} pts to next tier',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInQR extends StatelessWidget {
  final String userId;
  const _CheckInQR({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Quick Check-In', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            QrImageView(
              data: 'scales://checkin?singerId=$userId',
              size: 180,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 8),
            Text('Show this QR code at the venue',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  final List<SongHistoryItem> songs;
  const _SongList({required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No songs yet.'),
      );
    }
    return Column(
      children: songs
          .map(
            (s) => ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(s.songName),
              subtitle: Text('${s.artistName} · ${s.venueName ?? 'Unknown venue'}'),
              trailing: Text(
                '${s.playedAt.day}/${s.playedAt.month}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
          .toList(),
    );
  }
}
