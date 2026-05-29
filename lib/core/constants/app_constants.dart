/// Named route paths used by GoRouter or Navigator 2.0.
class RoutePaths {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String singerQueue = '/singer/queue';
  static const String singerProfile = '/singer/profile';
  static const String singerProfileEdit = '/singer/profile/edit';
  static const String checkIn = '/checkin';
  static const String leaderboard = '/leaderboard';
  static const String venueDetail = '/venue/:id';
}

/// API endpoint constants.
class ApiEndpoints {
  static const baseUrl = 'https://dancingdragonservices.com/api/v1';
  static String singerProfile(String singerId) => '/singers/$singerId/profile';
  static String checkIn(String venueId) => '/venues/$venueId/singers/checkin';
  static String leaderboard(String venueId) => '/venues/$venueId/leaderboard';
  static String songs(String venueId) => '/venues/$venueId/songs';
  static String songSearch(String venueId) => '/venues/$venueId/songs/search';
  static String songDetail(String venueId, String songId) =>
      '/venues/$venueId/songs/$songId';
  static const String followSinger = '/social/follow';
  static const String share = '/social/share';
}

/// HTTP status helpers.
class StatusCodes {
  static const int ok = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int notFound = 404;
  static const int serverError = 500;
}
