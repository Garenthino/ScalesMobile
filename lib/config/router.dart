import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/songs/song_browser_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/singer/singer_queue_screen.dart';
import '../presentation/screens/singer/singer_profile_screen.dart';
import '../presentation/screens/check_in/check_in_screen.dart';
import '../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../presentation/screens/venue/venue_detail_screen.dart';
import '../presentation/screens/singer/edit_profile_screen.dart';
import '../presentation/screens/onboarding/venue_onboarding_screen.dart';
import '../presentation/screens/onboarding/venue_qr_scanner_screen.dart';
import '../presentation/screens/venue/venue_switcher_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../core/constants/app_constants.dart';
import '../services/venue_storage.dart';

/// Async redirect guard that reads onboarding + auth state from local storage.
/// Returns the route path the user should be sent to, or null to allow.
Future<String?> _asyncRedirect(GoRouterState state, Ref ref) async {
  final path = state.uri.path;
  final storage = await VenueStorage.create();

  final onboardingComplete = storage.isOnboardingComplete();
  final activeVenueId = storage.getActiveVenueId();

  // Allow public routes unconditionally
  if (path == RoutePaths.splash || path == RoutePaths.onboarding) {
    return null;
  }

  // If no venue is set, force onboarding
  if (!onboardingComplete || activeVenueId == null) {
    return RoutePaths.onboarding;
  }

  // Check auth state via ref (no BuildContext across async gap)
  final authState = ref.read(authProvider);
  final isAuth = switch (authState) {
    Authenticated() => true,
    _ => false,
  };

  final isAuthRoute = path == RoutePaths.auth;

  if (isAuth && isAuthRoute) {
    return RoutePaths.home;
  }
  if (!isAuth && !isAuthRoute) {
    return RoutePaths.auth;
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) async {
      // Splash is allowed; it will redirect after a brief delay
      if (state.uri.path == RoutePaths.splash) return null;
      return await _asyncRedirect(state, ref);
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const VenueOnboardingScreen(),
      ),
      GoRoute(
        path: '/scan-qr',
        builder: (context, state) => const VenueQrScannerScreen(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.songBrowser,
        builder: (context, state) => const SongBrowserScreen(),
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
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.checkIn,
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: RoutePaths.leaderboard,
        builder: (context, state) {
          final venueId = state.extra as String?;
          return LeaderboardScreen(venueId: venueId ?? 'default_venue');
        },
      ),
      GoRoute(
        path: '/venue/switch',
        builder: (context, state) => const VenueSwitcherScreen(),
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

// Splash screen with branded fade-in animation.
// After animation completes, it navigates based on stored state.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
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
    _controller.forward().whenComplete(_onAnimationComplete);
  }

  Future<void> _onAnimationComplete() async {
    final storage = await VenueStorage.create();
    if (!mounted) return;

    final onboardingComplete = storage.isOnboardingComplete();
    final activeVenueId = storage.getActiveVenueId();

    if (!onboardingComplete || activeVenueId == null) {
      context.go(RoutePaths.onboarding);
      return;
    }

    final authState = ref.read(authProvider);
    if (authState is Authenticated) {
      context.go(RoutePaths.home);
    } else {
      context.go(RoutePaths.auth);
    }
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
              Icon(
                Icons.music_note,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
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
