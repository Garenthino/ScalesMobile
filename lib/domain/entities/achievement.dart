/// Achievement entity representing a singer's progress toward a milestone.
class Achievement {
  final String key;
  final String name;
  final String description;
  final String? icon;
  final int progress;
  final int target;
  final String? unlockedAt;
  final bool unlocked;

  const Achievement({
    required this.key,
    required this.name,
    required this.description,
    this.icon,
    required this.progress,
    required this.target,
    this.unlockedAt,
    required this.unlocked,
  });

  double get progressRatio => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
}
