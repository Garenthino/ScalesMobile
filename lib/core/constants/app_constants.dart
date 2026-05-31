/// Named route paths used by GoRouter or Navigator 2.0.
class RoutePaths {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String songBrowser = '/songs';
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
  static String queueJoin(String venueId) => '/venues/$venueId/queue/join';
  static String queueStatus(String venueId) => '/venues/$venueId/queue/status';
  static String queueLeave(String venueId) => '/venues/$venueId/queue/leave';
  static String queueVenue(String venueId) => '/venues/$venueId/queue/venue';
  static String myQueue(String venueId) => '/venues/$venueId/singers/me/queue';
  static String myQueueHistory(String venueId) => '/venues/$venueId/singers/me/queue/history';
  static String follow(String venueId, String followeeId) =>
      '/venues/$venueId/singers/follow/$followeeId';
  static String followStatus(String venueId, String followeeId) =>
      '/venues/$venueId/singers/follow/status/$followeeId';
  static String share(String venueId) => '/venues/$venueId/leaderboard/share';
  static String favorites(String venueId) => '/venues/$venueId/singers/favorites';
  static String removeFavorite(String venueId, String songId) =>
      '/venues/$venueId/singers/favorites/$songId';
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
