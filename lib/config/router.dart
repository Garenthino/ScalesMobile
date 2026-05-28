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
      final isAuth = switch (authState) {
        Authenticated() => true,
        _ => false,
      };
      final isSplash = state.uri.path == RoutePaths.splash;
      final isAuthRoute = state.uri.path == RoutePaths.auth;

      // Unauthenticated users: can stay on splash or auth; go to auth elsewhere
      if (!isAuth) {
        if (isSplash || isAuthRoute) return null;
        return RoutePaths.auth;
      }

      // Authenticated users: boot away from splash/auth to home
      if (isAuth && (isSplash || isAuthRoute)) return RoutePaths.home;

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

// Splash screen with branding and minimum display duration
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Scales',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
