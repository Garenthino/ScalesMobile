import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Real implementation of singer profile repository backed by the Scales API.
class SingerProfileRepositoryImpl implements SingerProfileRepository {
  final Dio _dio;

  SingerProfileRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  Future<String?> _getActiveVenueId() async {
    final storage = await VenueStorage.create();
    return storage.getActiveVenueId();
  }

  Future<Map<String, dynamic>> _authHeaders() async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) return {};
    final storage = await VenueStorage.create();
    final token = storage.getToken(venueId);
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  @override
  Future<SingerProfile> fetchProfile(String singerId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.get(
        '/venues/$venueId/singers/$singerId',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final history = await fetchSongHistory(singerId);
        final favorites = await fetchFavoriteSongs(singerId);
        return _mapSingerProfile(data, history: history, favorites: favorites);
      }
      throw Exception('Failed to fetch profile: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  SingerProfile _mapSingerProfile(Map<String, dynamic> data, {List<SongHistoryItem> history = const [], List<SongHistoryItem> favorites = const []}) {
    final points = (data['total_points'] as num?)?.toInt() ?? 0;
    final tierData = data['loyalty_tier'] as Map<String, dynamic>?;
    final tier = tierData != null
        ? LoyaltyTier(
            name: tierData['name'] as String? ?? 'Member',
            points: (tierData['points'] as num?)?.toInt() ?? points,
            pointsToNextTier: (tierData['points_to_next_tier'] as num?)?.toInt() ?? 100,
            color: tierData['color'] as String? ?? '#4CAF50',
          )
        : LoyaltyTier(
            name: 'Member',
            points: points,
            pointsToNextTier: 100,
            color: '#4CAF50',
          );

    return SingerProfile(
      id: data['id'] as String? ?? '',
      name: data['stage_name'] as String? ?? 'Unknown',
      bio: data['bio'] as String? ?? data['pronouns'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      performancesCount: history.length,
      followersCount: 0,
      followingCount: 0,
      tier: tier,
      songHistory: history,
      favoriteSongs: favorites,
    );
  }

  @override
  Future<SingerProfile> updateProfile(
    String singerId, {
    String? name,
    String? bio,
    String? avatarUrl,
  }) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    final body = <String, dynamic>{};
    if (name != null) body['stage_name'] = name;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    try {
      final response = await _dio.put(
        '/venues/$venueId/singers/$singerId',
        data: body,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _mapSingerProfile(data);
      }
      throw Exception('Failed to update profile: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  @override
  Future<List<SongHistoryItem>> fetchSongHistory(String singerId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.get(
        '/venues/$venueId/singers/$singerId/history',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final List<dynamic> rawList;
        if (response.data is List) {
          rawList = response.data as List<dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          rawList = (response.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        } else {
          rawList = [];
        }
        return rawList.map((e) => _mapHistoryItem(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  SongHistoryItem _mapHistoryItem(Map<String, dynamic> data) {
    final playedAtRaw = data['created_at'] ?? data['played_at'];
    return SongHistoryItem(
      id: data['id']?.toString() ?? '',
      songName: data['song_title'] as String? ?? data['song_name'] as String? ?? 'Unknown',
      artistName: data['artist'] as String? ?? data['artist_name'] as String? ?? 'Unknown',
      playedAt: playedAtRaw != null
          ? DateTime.tryParse(playedAtRaw as String) ?? DateTime.now()
          : DateTime.now(),
      venueName: data['venue_name'] as String?,
    );
  }

  @override
  Future<List<SongHistoryItem>> fetchFavoriteSongs(String singerId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.get(
        '/venues/$venueId/singers/favorites',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((e) => _mapFavoriteItem(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      return [];
    }
  }

  SongHistoryItem _mapFavoriteItem(Map<String, dynamic> data) {
    final createdAtRaw = data['created_at'] as String?;
    return SongHistoryItem(
      id: data['song_id']?.toString() ?? data['id']?.toString() ?? '',
      songName: data['title'] as String? ?? 'Unknown',
      artistName: data['artist'] as String? ?? 'Unknown',
      playedAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
          : DateTime.now(),
      venueName: null,
    );
  }

  @override
  Future<void> addFavoriteSong(String singerId, SongHistoryItem song) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.post(
        '/venues/$venueId/singers/favorites',
        data: {'song_id': song.id},
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to add favorite: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Song not found in this venue');
      }
      rethrow;
    }
  }

  @override
  Future<void> removeFavoriteSong(String singerId, String songId) async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.delete(
        '/venues/$venueId/singers/favorites/$songId',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to remove favorite: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Favorite not found');
      }
      rethrow;
    }
  }
}
