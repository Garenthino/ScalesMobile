import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/auth_provider.dart';
import 'package:scales_mobile/presentation/providers/profile_provider.dart';
import 'package:scales_mobile/presentation/providers/social_provider.dart';

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
          // Social actions (share with self)
          _SocialActionsRow(profile: profile),
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

class _FollowStatusChip extends ConsumerStatefulWidget {
  final SingerProfile profile;
  const _FollowStatusChip({required this.profile});

  @override
  ConsumerState<_FollowStatusChip> createState() => _FollowStatusChipState();
}

class _FollowStatusChipState extends ConsumerState<_FollowStatusChip> {
  bool _loading = false;

  void _showSnack(String message) {
    if (!mounted) return;
    final ctx = context; // safe: mounted checked and this is State.context
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) return const SizedBox.shrink();

    final followAsync = ref.watch(
      followStatusProvider(
        (followerId: currentUserId, followeeId: widget.profile.id),
      ),
    );

    final isFollowing = switch (followAsync) {
      AsyncData(:final value) => value,
      _ => false,
    };

    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return ActionChip(
      avatar: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
      label: Text(isFollowing ? 'Unfollow' : 'Follow'),
      onPressed: () async {
        setState(() => _loading = true);
        final mutation = ref.read(followMutationProvider);
        try {
          if (isFollowing) {
            await mutation.unfollow(currentUserId, widget.profile.id);
            _showSnack('Unfollowed ${widget.profile.name}');
          } else {
            await mutation.follow(currentUserId, widget.profile.id);
            _showSnack('Followed ${widget.profile.name}');
          }
        } catch (e) {
          _showSnack('Error: $e');
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      },
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
