import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/domain/entities/achievement.dart';
import 'package:scales_mobile/presentation/providers/achievements_provider.dart';

/// Achievements screen showing unlocked and locked achievements.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: achievementsAsync.when(
        data: (achievements) => _AchievementsBody(achievements: achievements),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(achievementsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementsBody extends StatefulWidget {
  final List<Achievement> achievements;
  const _AchievementsBody({required this.achievements});

  @override
  State<_AchievementsBody> createState() => _AchievementsBodyState();
}

class _AchievementsBodyState extends State<_AchievementsBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Set<String> _shownConfetti = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AchievementsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger confetti for newly unlocked achievements
    for (final a in widget.achievements) {
      if (a.unlocked && !_shownConfetti.contains(a.key)) {
        _shownConfetti.add(a.key);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.achievements.where((a) => a.unlocked).toList();
    final locked = widget.achievements.where((a) => !a.unlocked).toList();

    return RefreshIndicator(
      onRefresh: () async {
        // Triggered by pull-to-refresh via Riverpod refresh
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (unlocked.isNotEmpty) ...[
            _SectionTitle(title: 'Unlocked (${unlocked.length})'),
            const SizedBox(height: 8),
            ...unlocked.asMap().entries.map((entry) {
              final index = entry.key;
              final achievement = entry.value;
              return _AchievementCard(
                achievement: achievement,
                delay: index * 0.08,
                controller: _controller,
                showConfetti: !_shownConfetti.contains(achievement.key),
                onConfettiShown: () => _shownConfetti.add(achievement.key),
              );
            }),
            const SizedBox(height: 24),
          ],
          if (locked.isNotEmpty) ...[
            _SectionTitle(title: 'In Progress (${locked.length})'),
            const SizedBox(height: 8),
            ...locked.asMap().entries.map((entry) {
              final index = entry.key;
              final achievement = entry.value;
              return _AchievementCard(
                achievement: achievement,
                delay: (unlocked.length + index) * 0.05,
                controller: _controller,
              );
            }),
          ],
          if (widget.achievements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('No achievements available yet.'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _AchievementCard extends StatefulWidget {
  final Achievement achievement;
  final double delay;
  final AnimationController controller;
  final bool showConfetti;
  final VoidCallback? onConfettiShown;

  const _AchievementCard({
    required this.achievement,
    required this.delay,
    required this.controller,
    this.showConfetti = false,
    this.onConfettiShown,
  });

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.showConfetti) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.forward();
        widget.onConfettiShown?.call();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.achievement;

    final anim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Interval(
          widget.delay.clamp(0.0, 0.85),
          (widget.delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.8 + (anim.value * 0.2),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: a.unlocked ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: a.unlocked
              ? BorderSide.none
              : BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
        ),
        color: a.unlocked
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _AchievementIcon(unlocked: a.unlocked, icon: a.icon),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: a.unlocked
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProgressBar(achievement: a),
                        const SizedBox(height: 4),
                        Text(
                          '${a.progress} / ${a.target}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (a.unlocked)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: (1 - _confettiController.value).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1.0 + _confettiController.value * 0.5,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    Icons.emoji_events,
                    color: const Color(0xFFFFD700),
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  final bool unlocked;
  final String? icon;
  const _AchievementIcon({required this.unlocked, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 26,
      backgroundColor: unlocked
          ? theme.colorScheme.primary.withValues(alpha: 0.2)
          : theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        _resolveIcon(icon),
        size: 24,
        color: unlocked
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  IconData _resolveIcon(String? key) {
    return switch (key?.toLowerCase()) {
      'mic' || 'microphone' => Icons.mic,
      'music' || 'song' => Icons.music_note,
      'star' => Icons.star,
      'heart' || 'love' => Icons.favorite,
      'people' || 'fans' => Icons.people,
      'calendar' || 'regular' => Icons.calendar_month,
      'trophy' || 'winner' => Icons.emoji_events,
      'money' || 'tip' || 'cash' => Icons.attach_money,
      null || '' => Icons.emoji_events,
      _ => Icons.emoji_events,
    };
  }
}

class _ProgressBar extends StatelessWidget {
  final Achievement achievement;
  const _ProgressBar({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = achievement.progressRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 8,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          achievement.unlocked
              ? const Color(0xFF4CAF50)
              : theme.colorScheme.primary,
        ),
      ),
    );
  }
}
