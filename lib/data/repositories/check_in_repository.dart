import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

class CheckInRepositoryImpl implements CheckInRepository {
  @override
  Future<CheckInResult> checkIn(String venueId, String singerId, {String? code}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (venueId == 'invalid' || code == '000000') {
      return const CheckInResult(
        success: false,
        message: 'Invalid venue or code. Please try again.',
      );
    }
    return CheckInResult(
      success: true,
      venueId: venueId,
      venueName: 'The Golden Mic',
      queuePosition: 3,
      message: 'You are #3 in the queue. Estimated wait: ~15 min',
    );
  }

  @override
  Future<CheckInResult> getCurrentCheckIn(String singerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock that singer is not currently checked in anywhere
    return const CheckInResult(
      success: false,
      message: 'Not checked into any venue',
    );
  }
}
