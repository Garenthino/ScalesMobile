import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/repositories/singer_profile_repository.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';

final singerProfileRepoProvider = Provider<SingerProfileRepository>(
  (_) => SingerProfileRepositoryImpl(),
);

/// Provider that fetches the current user's own profile via /me.
final myProfileProvider = FutureProvider.autoDispose<SingerProfile>((ref) async {
  final repo = ref.watch(singerProfileRepoProvider);
  return repo.fetchMyProfile();
});

/// Provider that fetches a singer's profile by ID.
final singerProfileProvider = FutureProvider.autoDispose
    .family<SingerProfile, String>((ref, singerId) async {
  final repo = ref.watch(singerProfileRepoProvider);
  return repo.fetchProfile(singerId);
});

/// Provider for own stats via /me/stats.
final myStatsProvider = FutureProvider.autoDispose<SingerStats>((ref) async {
  final repo = ref.watch(singerProfileRepoProvider);
  return repo.fetchMyStats();
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

/// Notifier to mutate favorites and invalidate the cached list.
final favoriteMutationProvider = Provider<FavoriteMutation>((ref) {
  return FavoriteMutation(
    repo: ref.read(singerProfileRepoProvider),
    invalidate: () {
      ref.invalidate(favoriteSongsProvider);
      ref.invalidate(myProfileProvider);
    },
  );
});

class FavoriteMutation {
  final SingerProfileRepository _repo;
  final void Function() _invalidate;

  const FavoriteMutation({
    required this._repo,
    required this._invalidate,
  });

  Future<void> addFavorite(String singerId, SongHistoryItem song) async {
    await _repo.addFavoriteSong(singerId, song);
    _invalidate();
  }

  Future<void> removeFavorite(String singerId, String songId) async {
    await _repo.removeFavoriteSong(singerId, songId);
    _invalidate();
  }
}
