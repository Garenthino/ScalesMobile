import 'package:scales_mobile/domain/entities/achievement.dart';

/// Repository for singer achievements.
abstract class AchievementRepository {
  /// Fetch the current singer's achievements for the active venue.
  Future<List<Achievement>> fetchMyAchievements();
}
