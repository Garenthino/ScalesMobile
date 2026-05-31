import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/repositories/achievement_repository.dart';
import 'package:scales_mobile/domain/entities/achievement.dart';
import 'package:scales_mobile/domain/repositories/achievement_repository.dart';

final achievementRepoProvider = Provider<AchievementRepository>(
  (_) => AchievementRepositoryImpl(),
);

/// Provider for fetching the current singer's achievements.
final achievementsProvider = FutureProvider.autoDispose<List<Achievement>>((ref) async {
  final repo = ref.watch(achievementRepoProvider);
  return repo.fetchMyAchievements();
});
