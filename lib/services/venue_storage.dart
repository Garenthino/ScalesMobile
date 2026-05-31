import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Data class for a cached venue configuration.
class CachedVenue {
  final String id;
  final String name;
  final String slug;
  final String venueCode;
  final String timezone;
  final String? logoUrl;
  final String? primaryColor;
  final String? welcomeMessage;
  final bool isActive;

  const CachedVenue({
    required this.id,
    required this.name,
    required this.slug,
    required this.venueCode,
    required this.timezone,
    this.logoUrl,
    this.primaryColor,
    this.welcomeMessage,
    this.isActive = true,
  });

  factory CachedVenue.fromJson(Map<String, dynamic> json) {
    return CachedVenue(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      venueCode: json['venue_code'] as String,
      timezone: json['timezone'] as String,
      logoUrl: json['logo_url'] as String?,
      primaryColor: json['primary_color'] as String?,
      welcomeMessage: json['welcome_message'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'venue_code': venueCode,
    'timezone': timezone,
    'logo_url': logoUrl,
    'primary_color': primaryColor,
    'welcome_message': welcomeMessage,
    'is_active': isActive,
  };

  @override
  String toString() => 'CachedVenue($venueCode: $name)';
}

/// Multi-venue local storage backed by SharedPreferences.
///
/// Supports switching venues while preserving per-venue auth tokens,
/// loyalty state, and settings independently.
class VenueStorage {
  static const _refreshTokenPrefix = 'scales_refresh_';
  static const _venuesKey = 'scales_venues';
  static const _activeVenueKey = 'scales_active_venue_id';
  static const _authPrefix = 'scales_auth_';
  static const _onboardingCompleteKey = 'scales_onboarding_complete';

  late final SharedPreferences _prefs;

  VenueStorage._();

  static Future<VenueStorage> create() async {
    final storage = VenueStorage._();
    storage._prefs = await SharedPreferences.getInstance();
    return storage;
  }

  // ------------------------------------------------------------------
  // Venue list
  // ------------------------------------------------------------------

  List<CachedVenue> getVenues() {
    final raw = _prefs.getString(_venuesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => CachedVenue.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveVenue(CachedVenue venue) async {
    final venues = getVenues();
    final idx = venues.indexWhere((v) => v.id == venue.id);
    if (idx >= 0) {
      venues[idx] = venue;
    } else {
      venues.add(venue);
    }
    await _prefs.setString(_venuesKey, jsonEncode(venues.map((v) => v.toJson()).toList()));
  }

  Future<void> removeVenue(String venueId) async {
    final venues = getVenues().where((v) => v.id != venueId).toList();
    await _prefs.setString(_venuesKey, jsonEncode(venues.map((v) => v.toJson()).toList()));
    // Also clear auth for this venue
    await _prefs.remove('$_authPrefix$venueId');
    // If this was the active venue, clear it
    if (getActiveVenueId() == venueId) {
      await clearActiveVenue();
    }
  }

  // ------------------------------------------------------------------
  // Active venue
  // ------------------------------------------------------------------

  String? getActiveVenueId() => _prefs.getString(_activeVenueKey);

  Future<void> setActiveVenue(String venueId) async {
    await _prefs.setString(_activeVenueKey, venueId);
  }

  Future<void> clearActiveVenue() async {
    await _prefs.remove(_activeVenueKey);
  }

  CachedVenue? getActiveVenue() {
    final id = getActiveVenueId();
    if (id == null) return null;
    return getVenues().firstWhere(
      (v) => v.id == id,
      orElse: () => throw StateError('Active venue $id not found in cache'),
    );
  }

  // ------------------------------------------------------------------
  // Onboarding flag
  // ------------------------------------------------------------------

  bool isOnboardingComplete() => _prefs.getBool(_onboardingCompleteKey) ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingCompleteKey, value);
  }

  // ------------------------------------------------------------------
  // Per-venue auth token
  // ------------------------------------------------------------------

  String? getToken(String venueId) => _prefs.getString('$_authPrefix$venueId');

  Future<void> setToken(String venueId, String token) async {
    await _prefs.setString('$_authPrefix$venueId', token);
  }

  Future<void> clearToken(String venueId) async {
    await _prefs.remove('$_authPrefix$venueId');
  }

  // ------------------------------------------------------------------
  // Per-venue refresh token
  // ------------------------------------------------------------------

  String? getRefreshToken(String venueId) => _prefs.getString('$_refreshTokenPrefix$venueId');

  Future<void> setRefreshToken(String venueId, String token) async {
    await _prefs.setString('$_refreshTokenPrefix$venueId', token);
  }

  Future<void> clearRefreshToken(String venueId) async {
    await _prefs.remove('$_refreshTokenPrefix$venueId');
  }

  // ------------------------------------------------------------------
  // Last check-in cache
  // ------------------------------------------------------------------

  static const _achievementsPrefix = 'scales_achievements_';

  Future<void> saveAchievements(String venueId, List<Map<String, dynamic>> data) async {
    await _prefs.setString('$_achievementsPrefix$venueId', jsonEncode(data));
  }

  List<Map<String, dynamic>>? getAchievements(String venueId) {
    final raw = _prefs.getString('$_achievementsPrefix$venueId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  static const _lastCheckInKey = 'scales_last_checkin';

  Future<void> setLastCheckIn({required String venueId, required String venueName}) async {
    await _prefs.setString(_lastCheckInKey, jsonEncode({
      'venue_id': venueId,
      'venue_name': venueName,
      'checked_in_at': DateTime.now().toIso8601String(),
    }));
  }

  Map<String, dynamic>? getLastCheckIn() {
    final raw = _prefs.getString(_lastCheckInKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastCheckIn() async {
    await _prefs.remove(_lastCheckInKey);
  }

  // ------------------------------------------------------------------
  // Reset
  // ------------------------------------------------------------------

  Future<void> clearAll() async {
    await _prefs.remove(_venuesKey);
    await _prefs.remove(_activeVenueKey);
    await _prefs.remove(_onboardingCompleteKey);
    await _prefs.remove(_lastCheckInKey);
    // Remove all auth tokens
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_authPrefix) || key.startsWith(_refreshTokenPrefix)) {
        await _prefs.remove(key);
      }
    }
  }
}
