import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scales_mobile/data/datasources/api_client.dart';
import 'package:scales_mobile/data/repositories/song_repository.dart';
import 'package:scales_mobile/domain/entities/song.dart';
import 'package:scales_mobile/domain/repositories/song_repository.dart';

const _defaultSongPageSize = 20;

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepositoryImpl(dio: ref.watch(dioProvider));
});

class SongSearchState {
  final String query;
  final List<Song> songs;
  final int page;
  final bool hasMore;

  const SongSearchState({
    this.query = '',
    this.songs = const [],
    this.page = 1,
    this.hasMore = true,
  });

  SongSearchState copyWith({
    String? query,
    List<Song>? songs,
    int? page,
    bool? hasMore,
  }) {
    return SongSearchState(
      query: query ?? this.query,
      songs: songs ?? this.songs,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final songSearchProvider =
    NotifierProvider<SongSearchController, AsyncValue<SongSearchState>>(
      SongSearchController.new,
    );

/// Controller for query-based song browse/search state.
class SongSearchController extends Notifier<AsyncValue<SongSearchState>> {
  @override
  AsyncValue<SongSearchState> build() {
    return const AsyncData(SongSearchState());
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final songs = await _fetch(normalized, page: 1);
      return SongSearchState(
        query: normalized,
        songs: songs,
        page: 1,
        hasMore: songs.length == _defaultSongPageSize,
      );
    });
  }

  Future<void> loadInitial() => search('');

  Future<void> loadNextPage() async {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (current == null || !current.hasMore || state.isLoading) return;

    final nextPage = current.page + 1;
    state = const AsyncLoading<SongSearchState>();
    state = await AsyncValue.guard(() async {
      final nextSongs = await _fetch(current.query, page: nextPage);
      return current.copyWith(
        songs: [...current.songs, ...nextSongs],
        page: nextPage,
        hasMore: nextSongs.length == _defaultSongPageSize,
      );
    });
  }

  void clear() {
    state = const AsyncData(SongSearchState());
  }

  Future<List<Song>> _fetch(String query, {required int page}) {
    final repository = ref.read(songRepositoryProvider);
    if (query.isEmpty) {
      return repository.fetchSongs(page: page, perPage: _defaultSongPageSize);
    }
    return repository.searchSongs(
      query,
      page: page,
      perPage: _defaultSongPageSize,
    );
  }
}
