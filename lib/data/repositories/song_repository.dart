import 'package:dio/dio.dart';
import 'package:scales_mobile/core/constants/app_constants.dart';
import 'package:scales_mobile/data/models/song_model.dart';
import 'package:scales_mobile/domain/entities/song.dart';
import 'package:scales_mobile/domain/repositories/song_repository.dart';
import 'package:scales_mobile/services/venue_storage.dart';

/// Real implementation of song catalog repository backed by the Scales API.
class SongRepositoryImpl implements SongRepository {
  final Dio _dio;

  SongRepositoryImpl({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiEndpoints.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  Future<String> _activeVenueId() async {
    final storage = await VenueStorage.create();
    final venueId = storage.getActiveVenueId();
    if (venueId == null || venueId.isEmpty) {
      throw Exception('No active venue selected.');
    }
    return venueId;
  }

  @override
  Future<List<Song>> fetchSongs({
    int page = 1,
    int perPage = 20,
    String? query,
  }) async {
    final venueId = await _activeVenueId();
    final queryParameters = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };

    try {
      final response = await _dio.get(
        ApiEndpoints.songs(venueId),
        queryParameters: queryParameters,
      );
      return _songsFromResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  @override
  Future<List<Song>> searchSongs(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async {
    final venueId = await _activeVenueId();
    try {
      final response = await _dio.get(
        ApiEndpoints.songSearch(venueId),
        queryParameters: {'q': query.trim(), 'page': page, 'per_page': perPage},
      );
      return _songsFromResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  @override
  Future<Song> fetchSong(String songId) async {
    final venueId = await _activeVenueId();
    try {
      final response = await _dio.get(ApiEndpoints.songDetail(venueId, songId));
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return SongModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to fetch song: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      rethrow;
    }
  }

  List<Song> _songsFromResponse(Response<dynamic> response) {
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch songs: ${response.statusCode}');
    }

    final rawList = _extractList(response.data);
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(SongModel.fromJson)
        .toList(growable: false);
  }

  List<dynamic> _extractList(Object? data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final raw = data['data'] ?? data['items'] ?? data['results'];
      if (raw is List<dynamic>) return raw;
    }
    return const [];
  }
}
