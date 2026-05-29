import 'package:scales_mobile/domain/entities/song.dart';

/// Repository that defines song catalog browse/search operations.
abstract class SongRepository {
  Future<List<Song>> fetchSongs({
    int page = 1,
    int perPage = 20,
    String? query,
  });

  Future<List<Song>> searchSongs(
    String query, {
    int page = 1,
    int perPage = 20,
  });

  Future<Song> fetchSong(String songId);
}
