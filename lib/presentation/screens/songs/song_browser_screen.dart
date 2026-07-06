import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/queue_request.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/entities/song.dart';
import 'package:scales_mobile/presentation/providers/auth_provider.dart';
import 'package:scales_mobile/presentation/providers/profile_provider.dart';
import 'package:scales_mobile/presentation/providers/queue_provider.dart';
import 'package:scales_mobile/presentation/providers/song_search_provider.dart';
import 'package:scales_mobile/services/venue_storage.dart';

class SongBrowserScreen extends ConsumerStatefulWidget {
  const SongBrowserScreen({super.key});

  @override
  ConsumerState<SongBrowserScreen> createState() => _SongBrowserScreenState();
}

class _SongBrowserScreenState extends ConsumerState<SongBrowserScreen> {
  final _searchController = TextEditingController();
  final Set<String> _favoriteSongIds = <String>{};
  final Set<String> _syncingFavoriteIds = <String>{};
  final Set<String> _requestingSongIds = <String>{};

  String? _selectedGenre;
  int? _selectedDecade;
  CachedVenue? _activeVenue;
  QueueJoinResult? _lastQueueResult;
  bool _isLoadingVenue = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVenue());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songSearchProvider.notifier).loadInitial();
    });
    unawaited(_loadFavorites());
  }

  Future<void> _loadVenue() async {
    final storage = await VenueStorage.create();
    if (!mounted) return;
    setState(() {
      _activeVenue = storage.getActiveVenue();
      _isLoadingVenue = false;
    });
  }

  Future<void> _loadFavorites() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    final token = venueId != null ? storage.getToken(venueId) : null;
    if (token == null || token.isEmpty) return;

    try {
      final repo = ref.read(singerProfileRepoProvider);
      final authState = ref.read(authProvider);
      final userId = switch (authState) {
        Authenticated(:final activeSingerId) => activeSingerId,
        _ => null,
      };
      if (userId == null) return;

      final favorites = await repo.fetchFavoriteSongs(userId);
      if (!mounted) return;
      setState(() {
        _favoriteSongIds.clear();
        _favoriteSongIds.addAll(favorites.map((f) => f.id));
      });
    } catch (_) {
      // Silently ignore favorite load failures—stub time for song list
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _clearLocalFilters();
      ref.read(songSearchProvider.notifier).search(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _clearLocalFilters();
    ref.read(songSearchProvider.notifier).search('');
  }

  void _clearLocalFilters() {
    if (_selectedGenre == null && _selectedDecade == null) return;
    setState(() {
      _selectedGenre = null;
      _selectedDecade = null;
    });
  }

  Future<void> _toggleFavorite(Song song) async {
    final isCurrentlyFavorite = _favoriteSongIds.contains(song.id);
    setState(() {
      _syncingFavoriteIds.add(song.id);
      if (isCurrentlyFavorite) {
        _favoriteSongIds.remove(song.id);
      } else {
        _favoriteSongIds.add(song.id);
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    final mutation = ref.read(favoriteMutationProvider);

    final authState = ref.read(authProvider);
    final userId = switch (authState) {
      Authenticated(:final activeSingerId) => activeSingerId,
      _ => null,
    };
    if (userId == null) {
      setState(() {
        if (isCurrentlyFavorite) {
          _favoriteSongIds.add(song.id);
        } else {
          _favoriteSongIds.remove(song.id);
        }
        _syncingFavoriteIds.remove(song.id);
      });
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to save favorites')),
      );
      return;
    }

    try {
      if (isCurrentlyFavorite) {
        await mutation.removeFavorite(userId, song.id);
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Removed "${song.displayTitle}" from favorites')),
        );
      } else {
        await mutation.addFavorite(
          userId,
          SongHistoryItem(
            id: song.id,
            songName: song.displayTitle,
            artistName: song.displayArtist,
            playedAt: DateTime.now(),
          ),
        );
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Added "${song.displayTitle}" to favorites')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      // Revert optimistic change on failure
      setState(() {
        if (isCurrentlyFavorite) {
          _favoriteSongIds.add(song.id);
        } else {
          _favoriteSongIds.remove(song.id);
        }
      });
      final message = _cleanError(error);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update favorite: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncingFavoriteIds.remove(song.id);
        });
      }
    }
  }

  Future<void> _requestSong(Song song) async {
    final venue = _activeVenue;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (venue == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Select an active venue before requesting a song.'),
        ),
      );
      return;
    }

    if (!song.isAvailable) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This song is currently unavailable.')),
      );
      return;
    }

    if (_requestingSongIds.contains(song.id)) return;

    setState(() {
      _requestingSongIds.add(song.id);
      _lastQueueResult = null;
    });

    try {
      final result = await ref
          .read(queueRepositoryProvider)
          .joinQueue(venueId: venue.id, songId: song.id);
      ref.invalidate(myQueueProvider(venue.id));
      if (!mounted) return;
      setState(() {
        _lastQueueResult = result;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.warning?.isNotEmpty == true
                ? '${result.warning} Position #${result.estimatedPosition}.'
                : 'Requested "${song.displayTitle}". You are #${result.estimatedPosition} in queue.',
          ),
          action: SnackBarAction(
            label: 'My Queue',
            onPressed: () => context.go(RoutePaths.singerQueue),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(_cleanError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _requestingSongIds.remove(song.id);
        });
      }
    }
  }

  String _cleanError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  List<Song> _applyFilters(List<Song> songs) {
    return songs
        .where((song) {
          final genreMatches =
              _selectedGenre == null || song.genre == _selectedGenre;
          final decadeMatches =
              _selectedDecade == null ||
              _decadeFor(song.year) == _selectedDecade;
          return genreMatches && decadeMatches;
        })
        .toList(growable: false);
  }

  List<String> _availableGenres(List<Song> songs) {
    final genres =
        songs
            .map((song) => song.genre?.trim())
            .whereType<String>()
            .where((genre) => genre.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return genres;
  }

  List<int> _availableDecades(List<Song> songs) {
    final decades =
        songs
            .map((song) => _decadeFor(song.year))
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return decades;
  }

  int? _decadeFor(int? year) {
    if (year == null || year <= 0) return null;
    return (year ~/ 10) * 10;
  }

  @override
  Widget build(BuildContext context) {
    final songState = ref.watch(songSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Songs'),
        actions: [
          IconButton(
            tooltip: 'Refresh songs',
            onPressed: () {
              _clearLocalFilters();
              ref
                  .read(songSearchProvider.notifier)
                  .search(_searchController.text);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _Header(venue: _activeVenue, isLoadingVenue: _isLoadingVenue),
          if (_lastQueueResult != null)
            _QueueRequestResult(
              result: _lastQueueResult!,
              onViewQueue: () => context.go(RoutePaths.singerQueue),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search songs',
                hintText: 'Title, artist, album, or genre',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
              onSubmitted: (value) {
                _searchDebounce?.cancel();
                _clearLocalFilters();
                ref.read(songSearchProvider.notifier).search(value);
              },
            ),
          ),
          Expanded(
            child: songState.when(
              data: (state) {
                final filteredSongs = _applyFilters(state.songs);
                return Column(
                  children: [
                    _FilterBar(
                      genres: _availableGenres(state.songs),
                      decades: _availableDecades(state.songs),
                      selectedGenre: _selectedGenre,
                      selectedDecade: _selectedDecade,
                      onGenreSelected: (genre) {
                        setState(() {
                          _selectedGenre = _selectedGenre == genre
                              ? null
                              : genre;
                        });
                      },
                      onDecadeSelected: (decade) {
                        setState(() {
                          _selectedDecade = _selectedDecade == decade
                              ? null
                              : decade;
                        });
                      },
                      onClear: _clearLocalFilters,
                    ),
                    Expanded(
                      child: _SongResults(
                        songs: filteredSongs,
                        totalSongCount: state.songs.length,
                        query: state.query,
                        hasMore: state.hasMore,
                        hasActiveFilters:
                            _selectedGenre != null || _selectedDecade != null,
                        favoriteSongIds: _favoriteSongIds,
                        syncingFavoriteIds: _syncingFavoriteIds,
                        requestingSongIds: _requestingSongIds,
                        onFavoriteToggle: _toggleFavorite,
                        onRequestSong: _requestSong,
                        onRefresh: () => ref
                            .read(songSearchProvider.notifier)
                            .search(_searchController.text),
                        onLoadMore: () => ref
                            .read(songSearchProvider.notifier)
                            .loadNextPage(),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                error: error,
                onRetry: () => ref
                    .read(songSearchProvider.notifier)
                    .search(_searchController.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CachedVenue? venue;
  final bool isLoadingVenue;

  const _Header({required this.venue, required this.isLoadingVenue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = switch ((isLoadingVenue, venue)) {
      (true, _) => 'Loading active venue…',
      (false, final CachedVenue activeVenue) => activeVenue.name,
      _ => 'Using your active venue catalog',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.library_music,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Song Catalog',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRequestResult extends StatelessWidget {
  final QueueJoinResult result;
  final VoidCallback onViewQueue;

  const _QueueRequestResult({required this.result, required this.onViewQueue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Song requested',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You are #${result.estimatedPosition} in the queue.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                if (result.warning?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.warning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(onPressed: onViewQueue, child: const Text('My Queue')),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<String> genres;
  final List<int> decades;
  final String? selectedGenre;
  final int? selectedDecade;
  final ValueChanged<String> onGenreSelected;
  final ValueChanged<int> onDecadeSelected;
  final VoidCallback onClear;

  const _FilterBar({
    required this.genres,
    required this.decades,
    required this.selectedGenre,
    required this.selectedDecade,
    required this.onGenreSelected,
    required this.onDecadeSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = selectedGenre != null || selectedDecade != null;
    final visibleGenres = genres.take(8).toList(growable: false);
    final visibleDecades = decades.take(6).toList(growable: false);

    return SizedBox(
      height: 56,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          if (hasActiveFilter) ...[
            ActionChip(
              avatar: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
              onPressed: onClear,
            ),
            const SizedBox(width: 8),
          ],
          if (visibleGenres.isEmpty)
            const InputChip(
              avatar: Icon(Icons.category, size: 18),
              label: Text('Genre unavailable'),
              onPressed: null,
            )
          else
            for (final genre in visibleGenres) ...[
              FilterChip(
                avatar: const Icon(Icons.category, size: 18),
                label: Text(genre),
                selected: selectedGenre == genre,
                onSelected: (_) => onGenreSelected(genre),
              ),
              const SizedBox(width: 8),
            ],
          if (visibleDecades.isEmpty)
            const InputChip(
              avatar: Icon(Icons.calendar_month, size: 18),
              label: Text('Decade unavailable'),
              onPressed: null,
            )
          else
            for (final decade in visibleDecades) ...[
              FilterChip(
                avatar: const Icon(Icons.calendar_month, size: 18),
                label: Text('${decade}s'),
                selected: selectedDecade == decade,
                onSelected: (_) => onDecadeSelected(decade),
              ),
              const SizedBox(width: 8),
            ],
          const Tooltip(
            message:
                'TODO: enable difficulty filtering when the song API exposes a difficulty field.',
            child: InputChip(
              avatar: Icon(Icons.speed, size: 18),
              label: Text('Difficulty TODO'),
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SongResults extends StatelessWidget {
  final List<Song> songs;
  final int totalSongCount;
  final String query;
  final bool hasMore;
  final bool hasActiveFilters;
  final Set<String> favoriteSongIds;
  final Set<String> syncingFavoriteIds;
  final Set<String> requestingSongIds;
  final ValueChanged<Song> onFavoriteToggle;
  final ValueChanged<Song> onRequestSong;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  const _SongResults({
    required this.songs,
    required this.totalSongCount,
    required this.query,
    required this.hasMore,
    required this.hasActiveFilters,
    required this.favoriteSongIds,
    required this.syncingFavoriteIds,
    required this.requestingSongIds,
    required this.onFavoriteToggle,
    required this.onRequestSong,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSongCount == 0) {
      return _EmptyState(query: query);
    }

    if (songs.isEmpty && hasActiveFilters) {
      return const _NoFilterMatchesState();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: songs.length + (hasMore && !hasActiveFilters ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= songs.length) {
            return OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('Load more songs'),
            );
          }

          final song = songs[index];
          return _SongCard(
            song: song,
            isFavorite: favoriteSongIds.contains(song.id),
            isSyncingFavorite: syncingFavoriteIds.contains(song.id),
            isRequesting: requestingSongIds.contains(song.id),
            onFavoriteToggle: () => onFavoriteToggle(song),
            onRequestSong: () => onRequestSong(song),
          );
        },
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final bool isFavorite;
  final bool isSyncingFavorite;
  final bool isRequesting;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onRequestSong;

  const _SongCard({
    required this.song,
    required this.isFavorite,
    required this.isSyncingFavorite,
    required this.isRequesting,
    required this.onFavoriteToggle,
    required this.onRequestSong,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _formatDuration(song.durationMs);
    final metadata = [
      if (song.genre != null && song.genre!.trim().isNotEmpty)
        song.genre!.trim(),
      if (song.year != null) song.year.toString(),
      ?duration,
      if (!song.isAvailable) 'Unavailable',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.music_note,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (song.album != null && song.album!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      song.album!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: metadata
                          .map(
                            (label) => Chip(
                              label: Text(label),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: isFavorite ? 'Remove favorite' : 'Favorite song',
                      onPressed: isSyncingFavorite ? null : onFavoriteToggle,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      color: isFavorite ? theme.colorScheme.primary : null,
                    ),
                    if (isSyncingFavorite)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: song.isAvailable && !isRequesting
                      ? onRequestSong
                      : null,
                  icon: isRequesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add),
                  label: Text(isRequesting ? 'Requesting' : 'Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return null;
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No songs found' : 'No songs available yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different title, artist, or genre.'
                  : 'The active venue has not published a song catalog yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilterMatchesState extends StatelessWidget {
  const _NoFilterMatchesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No songs match the selected filters. Clear filters to see all results.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load songs',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
