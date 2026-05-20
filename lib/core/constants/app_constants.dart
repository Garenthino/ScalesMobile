/// Named route paths used by GoRouter or Navigator 2.0.
class RoutePaths {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String singerQueue = '/singer/queue';
  static const String singerProfile = '/singer/profile';
  static const String venueDetail = '/venue/:id';
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
