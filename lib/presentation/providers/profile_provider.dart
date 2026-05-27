import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/repositories/singer_profile_repository.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

final singerProfileRepoProvider = Provider<SingerProfileRepository>(
  (_) => SingerProfileRepositoryImpl(),
);

/// Provider that fetches a singer's profile by ID.
final singerProfileProvider = FutureProvider.autoDispose
    .family<SingerProfile, String>((ref, singerId) async {
  final repo = ref.watch(singerProfileRepoProvider);
  return repo.fetchProfile(singerId);
});

/// Provider for song history.
final songHistoryProvider = FutureProvider.autoDispose
    .family<List<SongHistoryItem>, String>((ref, singerId) async {
  final repo = ref.watch(singerProfileRepoProvider);
  return repo.fetchSongHistory(singerId);
});

/// Provider for favorite songs.
final favoriteSongsProvider = FutureProvider.autoDispose
    .family<List<SongHistoryItem>, String>((ref, singerId) async {
  final repo = ref.watch(singerProfileRepoProvider);
  return repo.fetchFavoriteSongs(singerId);
});
