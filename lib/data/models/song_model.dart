import 'package:scales_mobile/domain/entities/song.dart';

/// Data model for SongOut responses from the Scales backend.
class SongModel extends Song {
  const SongModel({
    required super.id,
    required super.venueId,
    super.catalogId,
    required super.title,
    required super.artist,
    super.album,
    super.genre,
    super.category,
    super.language,
    super.durationMs,
    super.year,
    super.lyricsUrl,
    super.coverArtUrl,
    required super.isAvailable,
    required super.isActive,
    super.metaJson,
    super.createdAt,
    super.updatedAt,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      catalogId: json['catalog_id']?.toString(),
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString(),
      genre: json['genre']?.toString(),
      category: json['category']?.toString(),
      language: json['language']?.toString(),
      durationMs: _intOrNull(json['duration_ms']),
      year: _intOrNull(json['year']),
      lyricsUrl: json['lyrics_url']?.toString(),
      coverArtUrl: json['cover_art_url']?.toString(),
      isAvailable: _boolValue(json['is_available'], defaultValue: true),
      isActive: _boolValue(json['is_active'], defaultValue: true),
      metaJson: json['meta_json']?.toString(),
      createdAt: _dateOrNull(json['created_at']),
      updatedAt: _dateOrNull(json['updated_at']),
    );
  }

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _boolValue(Object? value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return defaultValue;
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
