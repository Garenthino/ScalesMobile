import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/auth_provider.dart';
import 'package:scales_mobile/presentation/providers/social_provider.dart';

/// Period filter for the leaderboard.
enum LeaderboardPeriod { week, month, allTime }

extension _LeaderboardPeriodLabel on LeaderboardPeriod {
  String get label {
    return switch (this) {
      LeaderboardPeriod.week => 'Week',
      LeaderboardPeriod.month => 'Month',
      LeaderboardPeriod.allTime => 'All Time',
    };
  }

  String get apiValue {
    return switch (this) {
      LeaderboardPeriod.week => 'week',
      LeaderboardPeriod.month => 'month',
      LeaderboardPeriod.allTime => 'alltime',
    };
  }
}

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String venueId;
  const LeaderboardScreen({super.key, required this.venueId});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  LeaderboardPeriod _period = LeaderboardPeriod.allTime;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(
      leaderboardProvider((venueId: widget.venueId, period: _period.apiValue)),
    );
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.venueId.length > 12
                            ? 'Venue: ${widget.venueId.substring(0, 12)}...'
                            : 'Venue: ${widget.venueId}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<LeaderboardPeriod>(
                  segments: [
                    ButtonSegment(
                      value: LeaderboardPeriod.week,
                      label: Text(LeaderboardPeriod.week.label),
                    ),
                    ButtonSegment(
                      value: LeaderboardPeriod.month,
                      label: Text(LeaderboardPeriod.month.label),
                    ),
                    ButtonSegment(
                      value: LeaderboardPeriod.allTime,
                      label: Text(LeaderboardPeriod.allTime.label),
                    ),
                  ],
                  selected: <LeaderboardPeriod>{_period},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      setState(() => _period = set.first);
                      _animController.forward(from: 0);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: leaderboardAsync.when(
        data: (entries) {
          _animController.forward(from: 0);
          return _LeaderboardView(
            entries: entries,
            venueId: widget.venueId,
            currentUserId: currentUserId,
            period: _period,
            animController: _animController,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _LeaderboardView extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String venueId;
  final String? currentUserId;
  final LeaderboardPeriod period;
  final AnimationController animController;

  const _LeaderboardView({
    required this.entries,
    required this.venueId,
    required this.currentUserId,
    required this.period,
    required this.animController,
  });

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
        final isMe = currentUserId != null && entry.singerId == currentUserId;
        final delay = index * 0.05;
        return _AnimatedRankCard(
          entry: entry,
          isMe: isMe,
          animController: animController,
          delay: delay,
        );
      },
    );
  }
}

class _AnimatedRankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final AnimationController animController;
  final double delay;

  const _AnimatedRankCard({
    required this.entry,
    required this.isMe,
    required this.animController,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final anim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animController,
        curve: Interval(
          delay.clamp(0.0, 0.9),
          (delay + 0.3).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - anim.value) * 20),
            child: child,
          ),
        );
      },
      child: _RankCard(entry: entry, isMe: isMe),
    );
  }
}

class _RankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;

  const _RankCard({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = entry.rank;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isMe ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMe
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      color: isMe ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 14),
            _Avatar(avatarUrl: entry.avatarUrl, rank: rank),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isMe ? theme.colorScheme.primary : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _PointsDisplay(points: entry.points),
                ],
              ),
            ),
            if (!isMe)
              _FollowButton(singerId: entry.singerId, name: entry.name),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _PointsDisplay extends StatefulWidget {
  final int points;
  const _PointsDisplay({required this.points});

  @override
  State<_PointsDisplay> createState() => _PointsDisplayState();
}

class _PointsDisplayState extends State<_PointsDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _animation;
  int _previousPoints = 0;

  @override
  void initState() {
    super.initState();
    _previousPoints = widget.points;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = IntTween(begin: 0, end: widget.points).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _PointsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _previousPoints = oldWidget.points;
      _animation = IntTween(begin: _previousPoints, end: widget.points).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value} pts',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => Colors.transparent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _rankColor();
    final isTop3 = rank <= 3;
    return CircleAvatar(
      radius: isTop3 ? 20 : 16,
      backgroundColor: isTop3 ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isTop3 ? 16 : 13,
          color: isTop3 ? Colors.black : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final int rank;
  const _Avatar({this.avatarUrl, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    return CircleAvatar(
      radius: isTop3 ? 28 : 24,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: avatarUrl == null
          ? Icon(
              Icons.person,
              size: isTop3 ? 28 : 24,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String singerId;
  final String name;
  const _FollowButton({required this.singerId, required this.name});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null || currentUserId == widget.singerId) {
      return const SizedBox.shrink();
    }

    final followAsync = ref.watch(
      followStatusProvider(
        (followerId: currentUserId, followeeId: widget.singerId),
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

    return IconButton(
      icon: Icon(
        isFollowing ? Icons.person_remove : Icons.person_add,
        size: 20,
        color: isFollowing ? Colors.red : Theme.of(context).colorScheme.primary,
      ),
      tooltip: isFollowing ? 'Unfollow' : 'Follow',
      onPressed: () async {
        setState(() => _loading = true);
        final mutation = ref.read(followMutationProvider);
        try {
          if (isFollowing) {
            await mutation.unfollow(currentUserId, widget.singerId);
            _showSnack('Unfollowed ${widget.name}');
          } else {
            await mutation.follow(currentUserId, widget.singerId);
            _showSnack('Followed ${widget.name}');
          }
        } catch (e) {
          _showSnack('Error: $e');
        } finally {
          setState(() => _loading = false);
        }
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
