import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/singer/singer_queue_screen.dart';
import '../presentation/screens/singer/singer_profile_screen.dart';
import '../presentation/screens/check_in/check_in_screen.dart';
import '../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../presentation/screens/venue/venue_detail_screen.dart';
import '../presentation/screens/singer/edit_profile_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      // Redirect to auth if not authenticated (except splash/auth paths)
      final isAuth = switch (authState) {
        Authenticated() => true,
        _ => false,
      };
      final isAuthRoute = state.uri.path == RoutePaths.splash ||
          state.uri.path == RoutePaths.auth;
      if (!isAuth && !isAuthRoute) return RoutePaths.auth;
      if (isAuth && isAuthRoute) return RoutePaths.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.singerQueue,
        builder: (context, state) => const SingerQueueScreen(),
      ),
      GoRoute(
        path: RoutePaths.singerProfile,
        builder: (context, state) => const SingerProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.singerProfileEdit,
        builder: (context, state) {
          final singerId = state.extra as String?;
          return EditProfileScreen(singerId: singerId ?? 'demo_user');
        },
      ),
      GoRoute(
        path: RoutePaths.checkIn,
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: RoutePaths.leaderboard,
        builder: (context, state) {
          final venueId = state.extra as String? ?? 'default_venue';
          return LeaderboardScreen(venueId: venueId);
        },
      ),
      GoRoute(
        path: RoutePaths.venueDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VenueDetailScreen(venueId: id);
        },
      ),
    ],
  );
});

// Stub splash screen until router is wired into MaterialApp
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
