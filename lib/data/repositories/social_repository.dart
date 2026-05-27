import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

class SocialRepositoryImpl implements SocialRepository {
  final Set<String> _following = {};

  @override
  Future<void> follow(String followerId, String followeeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _following.add(followeeId);
  }

  @override
  Future<void> unfollow(String followerId, String followeeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _following.remove(followeeId);
  }

  @override
  Future<bool> isFollowing(String followerId, String followeeId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _following.contains(followeeId);
  }

  @override
  Future<void> shareToSocial(SocialShare share) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock share: no-op for now
  }
}
