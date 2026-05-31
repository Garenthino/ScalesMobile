import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/auth_provider.dart';
import 'package:scales_mobile/presentation/providers/profile_provider.dart';
import 'package:scales_mobile/presentation/providers/social_provider.dart';

class SingerProfileScreen extends ConsumerStatefulWidget {
  const SingerProfileScreen({super.key});

  @override
  ConsumerState<SingerProfileScreen> createState() => _SingerProfileScreenState();
}

class _SingerProfileScreenState extends ConsumerState<SingerProfileScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(myProfileProvider);
    ref.invalidate(myStatsProvider);
    await ref.read(myProfileProvider.future);
    await ref.read(myStatsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final statsAsync = ref.watch(myStatsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () => context.push(RoutePaths.singerProfileEdit),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _ProfileBody(
          profile: profile,
          stats: statsAsync,
          userId: currentUserId ?? profile.id,
          onRefresh: _onRefresh,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading profile: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final SingerProfile profile;
  final AsyncValue<SingerStats> stats;
  final String userId;
  final Future<void> Function() onRefresh;

  const _ProfileBody({
    required this.profile,
    required this.stats,
    required this.userId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AvatarSection(profile: profile),
                  const SizedBox(height: 12),
                  _NameSection(profile: profile),
                  const SizedBox(height: 16),
                  _StatusChip(isCheckedIn: profile.isCheckedIn),
                  const SizedBox(height: 16),
                  _StatsSection(stats: stats, profile: profile),
                  const SizedBox(height: 24),
                  _TierCard(tier: profile.tier),
                  const SizedBox(height: 24),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    _SectionTitle(title: 'Bio'),
                    Text(
                      profile.bio!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (profile.socialLinks.isNotEmpty) ...[
                    _SectionTitle(title: 'Social Links'),
                    _SocialLinksRow(links: profile.socialLinks),
                    const SizedBox(height: 24),
                  ],
                  _TopSongsSection(stats: stats),
                  const SizedBox(height: 24),
                  _SocialActionsRow(profile: profile),
                  const SizedBox(height: 24),
                  _CheckInQR(userId: userId),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'Song History (${profile.songHistory.length})'),
                  _SongList(songs: profile.songHistory),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'Favorite Songs (${profile.favoriteSongs.length})'),
                  _SongList(songs: profile.favoriteSongs),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final SingerProfile profile;
  const _AvatarSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'avatar_${profile.id}',
      child: CircleAvatar(
        radius: 56,
        backgroundImage: profile.avatarUrl != null
            ? NetworkImage(profile.avatarUrl!)
            : null,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: profile.avatarUrl == null
            ? Icon(Icons.person,
                size: 56,
                color: Theme.of(context).colorScheme.onPrimaryContainer)
            : null,
      ),
    );
  }
}

class _NameSection extends StatelessWidget {
  final SingerProfile profile;
  const _NameSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          profile.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (profile.pronouns != null && profile.pronouns!.isNotEmpty)
          Text(
            profile.pronouns!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        if (profile.realName != null && profile.realName!.isNotEmpty)
          Text(
            profile.realName!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isCheckedIn;
  const _StatusChip({required this.isCheckedIn});

  @override
  Widget build(BuildContext context) {
    final color = isCheckedIn ? Colors.green : Colors.grey;
    final label = isCheckedIn ? 'Checked In' : 'Not Checked In';
    return Chip(
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }
}

class _StatsSection extends StatelessWidget {
  final AsyncValue<SingerStats> stats;
  final SingerProfile profile;
  const _StatsSection({required this.stats, required this.profile});

  @override
  Widget build(BuildContext context) {
    return stats.when(
      data: (s) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCard(label: 'Songs', value: '${s.songsSung}'),
          _StatCard(label: 'Check-ins', value: '${s.totalCheckins}'),
          _StatCard(label: 'Points', value: '${s.totalPoints}'),
        ],
      ),
      loading: () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCard(label: 'Songs', value: '${profile.performancesCount}'),
          const _StatCard(label: 'Check-ins', value: '—'),
          _StatCard(label: 'Points', value: '${profile.tier.points}'),
        ],
      ),
      error: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCard(label: 'Songs', value: '${profile.performancesCount}'),
          const _StatCard(label: 'Check-ins', value: '—'),
          _StatCard(label: 'Points', value: '${profile.tier.points}'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SocialLinksRow extends StatelessWidget {
  final List<SocialLink> links;
  const _SocialLinksRow({required this.links});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: links.map((l) => ActionChip(
        avatar: _socialIcon(l.platform),
        label: Text(l.platform),
        onPressed: () {}, // TODO: url_launcher
      )).toList(),
    );
  }

  Widget _socialIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('insta')) return const Icon(Icons.photo_camera, size: 16);
    if (p.contains('twit') || p.contains('x')) return const Icon(Icons.flutter_dash, size: 16);
    if (p.contains('face')) return const Icon(Icons.facebook, size: 16);
    if (p.contains('youtube')) return const Icon(Icons.video_library, size: 16);
    if (p.contains('tik')) return const Icon(Icons.music_video, size: 16);
    return const Icon(Icons.link, size: 16);
  }
}

class _TopSongsSection extends StatelessWidget {
  final AsyncValue<SingerStats> stats;
  const _TopSongsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return stats.when(
      data: (s) {
        if (s.topSongs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Top Songs'),
            ...s.topSongs.map((song) => _TopSongTile(song: song)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TopSongTile extends StatelessWidget {
  final TopSong song;
  const _TopSongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.audiotrack, size: 20),
      title: Text(song.title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: song.artist != null
          ? Text(song.artist!, style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: Chip(
        label: Text('${song.count}×'),
        labelStyle: Theme.of(context).textTheme.bodySmall,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
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

class _SocialActionsRow extends StatelessWidget {
  final SingerProfile profile;
  const _SocialActionsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ShareButton(profile: profile),
      ],
    );
  }
}

class _ShareButton extends ConsumerStatefulWidget {
  final SingerProfile profile;
  const _ShareButton({required this.profile});

  @override
  ConsumerState<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends ConsumerState<_ShareButton> {
  bool _loading = false;

  Future<void> _share() async {
    setState(() => _loading = true);
    try {
      await ref.read(socialRepoProvider).shareToSocial(
        SocialShare(
          singerId: widget.profile.id,
          platform: 'generic',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile shared!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share),
      label: const Text('Share Profile'),
      onPressed: _loading ? null : _share,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: 'scales://checkin?singerId=$userId',
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
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
              subtitle: Text('${s.artistName} · ${s.venueName ?? "Unknown venue"}'),
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
