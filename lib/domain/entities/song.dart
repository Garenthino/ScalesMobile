/// Song catalog entry returned by the Scales backend.
class Song {
  final String id;
  final String venueId;
  final String? catalogId;
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final String? category;
  final String? language;
  final int? durationMs;
  final int? year;
  final String? lyricsUrl;
  final String? coverArtUrl;
  final bool isAvailable;
  final bool isActive;
  final String? metaJson;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Song({
    required this.id,
    required this.venueId,
    this.catalogId,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    this.category,
    this.language,
    this.durationMs,
    this.year,
    this.lyricsUrl,
    this.coverArtUrl,
    required this.isAvailable,
    required this.isActive,
    this.metaJson,
    this.createdAt,
    this.updatedAt,
  });

  String get displayTitle => title.isEmpty ? 'Untitled song' : title;
  String get displayArtist => artist.isEmpty ? 'Unknown artist' : artist;
}
