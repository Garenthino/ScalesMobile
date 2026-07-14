import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/domain/repositories/singer_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Exception thrown when a profile update violates a venue-scoped uniqueness
/// constraint (e.g. stage name already taken in this venue).
class StageNameTakenException implements Exception {
  final String stageName;
  final String? message;

  const StageNameTakenException(this.stageName, {this.message});

  @override
  String toString() =>
      message ?? 'Stage name "$stageName" is already taken at this venue.';
}

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

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  SingerProfile _mapSingerProfile(Map<String, dynamic> data, {
    List<SongHistoryItem> history = const [],
    List<SongHistoryItem> favorites = const [],
  }) {
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

    final socialRaw = data['social_links'];
    List<SocialLink> socialLinks = [];
    if (socialRaw is List) {
      socialLinks = socialRaw.map((e) {
        final m = e as Map<String, dynamic>? ?? {};
        return SocialLink(
          platform: m['platform'] as String? ?? '',
          url: m['url'] as String? ?? '',
        );
      }).toList();
    } else if (socialRaw is Map) {
      socialLinks = (socialRaw as Map<String, dynamic>).entries
          .map((e) => SocialLink(platform: e.key, url: e.value.toString()))
          .toList();
    }

    final checkedInAtRaw = data['checked_in_at'] as String?;

    return SingerProfile(
      id: data['id'] as String? ?? '',
      name: data['stage_name'] as String? ?? data['display_name'] as String? ?? data['name'] as String? ?? 'Unknown',
      realName: data['real_name'] as String?,
      firstName: data['first_name'] as String?,
      lastName: data['last_name'] as String?,
      pronouns: data['pronouns'] as String?,
      phone: data['phone'] as String?,
      bio: data['bio'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      socialLinks: socialLinks,
      isCheckedIn: data['is_checked_in'] as bool? ?? false,
      checkedInAt: checkedInAtRaw != null ? DateTime.tryParse(checkedInAtRaw) : null,
      performancesCount: history.length,
      followersCount: (data['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (data['following_count'] as num?)?.toInt() ?? 0,
      tier: tier,
      songHistory: history,
      favoriteSongs: favorites,
    );
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

  // ------------------------------------------------------------------
  // Profile
  // ------------------------------------------------------------------

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

  @override
  Future<SingerProfile> fetchMyProfile() async {
    final storage = await VenueStorage.create();
    final accountToken = storage.getAccountToken();
    final venueId = storage.getActiveVenueId();

    try {
      Map<String, dynamic> data;
      if (accountToken != null && accountToken.isNotEmpty) {
        // Global account profile (cross-venue)
        final response = await _dio.get(
          '/accounts/me',
          options: Options(headers: {'Authorization': 'Bearer $accountToken'}),
        );
        if (response.statusCode == 200) {
          data = response.data as Map<String, dynamic>;
        } else {
          throw Exception('Failed to fetch account profile: ${response.statusCode}');
        }
      } else if (venueId != null) {
        // Legacy venue-scoped profile
        final response = await _dio.get(
          '/venues/$venueId/singers/me',
          options: Options(headers: await _authHeaders()),
        );
        if (response.statusCode == 200) {
          data = response.data as Map<String, dynamic>;
        } else {
          throw Exception('Failed to fetch my profile: ${response.statusCode}');
        }
      } else {
        throw Exception('No active account or venue');
      }

      final singerId = data['id'] as String? ?? '';
      final history = venueId != null && singerId.isNotEmpty
          ? await fetchSongHistory(singerId)
          : <SongHistoryItem>[];
      final favorites = venueId != null && singerId.isNotEmpty
          ? await fetchFavoriteSongs(singerId)
          : <SongHistoryItem>[];
      return _mapSingerProfile(data, history: history, favorites: favorites);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  @override
  Future<SingerProfile> updateMyProfile({
    String? stageName,
    String? realName,
    String? firstName,
    String? lastName,
    String? pronouns,
    String? phone,
    String? bio,
    List<SocialLink>? socialLinks,
  }) async {
    final storage = await VenueStorage.create();
    final accountToken = storage.getAccountToken();
    final venueId = storage.getActiveVenueId();
    if (accountToken == null && venueId == null) {
      throw Exception('No active account or venue');
    }
    final body = <String, dynamic>{};
    if (stageName != null) body['stage_name'] = stageName;
    final derivedRealName = [firstName, lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    if (derivedRealName.isNotEmpty) {
      body['first_name'] = firstName;
      body['last_name'] = lastName;
      body['real_name'] = derivedRealName;
    } else if (realName != null && realName.isNotEmpty) {
      body['real_name'] = realName;
    }
    if (pronouns != null) body['pronouns'] = pronouns;
    if (phone != null) body['phone'] = phone;
    if (bio != null) body['bio'] = bio;
    if (socialLinks != null) {
      body['social_links'] = socialLinks
          .map((l) => {'platform': l.platform, 'url': l.url})
          .toList();
    }

    try {
      final response = accountToken != null && accountToken.isNotEmpty
          ? await _dio.put(
              '/accounts/me',
              data: body,
              options: Options(headers: {'Authorization': 'Bearer $accountToken'}),
            )
          : await _dio.put(
              '/venues/$venueId/singers/me',
              data: body,
              options: Options(headers: await _authHeaders()),
            );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _mapSingerProfile(data);
      }
      if (response.statusCode == 409) {
        final detail = (response.data as Map<String, dynamic>?)?['detail'] as String?;
        throw StageNameTakenException(stageName ?? '', message: detail);
      }
      throw Exception('Failed to update profile: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (e.response?.statusCode == 409) {
        final detail = (e.response?.data as Map<String, dynamic>?)?['detail'] as String?;
        throw StageNameTakenException(stageName ?? '', message: detail);
      }
      rethrow;
    }
  }

  // ------------------------------------------------------------------
  // Avatar upload
  // ------------------------------------------------------------------

  @override
  Future<String?> uploadAvatar(
    XFile image, {
    void Function(double progress)? onProgress,
  }) async {
    final storage = await VenueStorage.create();
    final accountToken = storage.getAccountToken();
    final venueId = storage.getActiveVenueId();
    if (accountToken == null && venueId == null) {
      throw Exception('No active account or venue');
    }

    final filePath = image.path;
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    try {
      final response = accountToken != null && accountToken.isNotEmpty
          ? await _dio.post(
              '/accounts/me/avatar',
              data: formData,
              options: Options(headers: {'Authorization': 'Bearer $accountToken'}),
              onSendProgress: (sent, total) {
                if (total > 0 && onProgress != null) {
                  onProgress(sent / total);
                }
              },
            )
          : await _dio.post(
              '/venues/$venueId/singers/me/avatar',
              data: formData,
              options: Options(headers: await _authHeaders()),
              onSendProgress: (sent, total) {
                if (total > 0 && onProgress != null) {
                  onProgress(sent / total);
                }
              },
            );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>? ?? {};
        return data['avatar_url'] as String?;
      }
      throw Exception('Failed to upload avatar: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (e.response?.statusCode == 413) {
        throw Exception('Image too large. Max 5 MB.');
      }
      rethrow;
    }
  }

  // ------------------------------------------------------------------
  // Stats
  // ------------------------------------------------------------------

  @override
  Future<SingerStats> fetchMyStats() async {
    final venueId = await _getActiveVenueId();
    if (venueId == null) {
      throw Exception('No active venue');
    }
    try {
      final response = await _dio.get(
        '/venues/$venueId/singers/me/stats',
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final topRaw = data['top_songs'] as List<dynamic>? ?? [];
        final topSongs = topRaw.map((e) {
          final m = e as Map<String, dynamic>;
          return TopSong(
            id: m['id']?.toString() ?? '',
            title: m['title'] as String? ?? 'Unknown',
            artist: m['artist'] as String?,
            count: (m['count'] as num?)?.toInt() ?? 0,
          );
        }).toList();

        return SingerStats(
          songsSung: (data['songs_sung'] as num?)?.toInt() ?? 0,
          totalCheckins: (data['total_checkins'] as num?)?.toInt() ?? 0,
          totalPoints: (data['total_points'] as num?)?.toInt() ?? 0,
          topSongs: topSongs,
          avgWaitMin: (data['avg_wait_min'] as num?)?.toDouble(),
          favoriteGenre: data['favorite_genre'] as String?,
        );
      }
      throw Exception('Failed to fetch stats: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  // ------------------------------------------------------------------
  // Song history / favorites
  // ------------------------------------------------------------------

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
