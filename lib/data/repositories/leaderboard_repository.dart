import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard(String venueId, {int limit = 20}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      const LeaderboardEntry(
        singerId: 'usr_1',
        name: 'Alex Singer',
        avatarUrl: null,
        points: 1240,
        rank: 1,
      ),
      const LeaderboardEntry(
        singerId: 'usr_2',
        name: 'Maria',
        avatarUrl: null,
        points: 1150,
        rank: 2,
      ),
      const LeaderboardEntry(
        singerId: 'usr_3',
        name: 'DJ Sam',
        avatarUrl: null,
        points: 980,
        rank: 3,
      ),
      const LeaderboardEntry(
        singerId: 'usr_4',
        name: 'Lisa Tunes',
        avatarUrl: null,
        points: 920,
        rank: 4,
      ),
      const LeaderboardEntry(
        singerId: 'usr_5',
        name: 'Carlos',
        avatarUrl: null,
        points: 860,
        rank: 5,
      ),
    ];
  }
}
