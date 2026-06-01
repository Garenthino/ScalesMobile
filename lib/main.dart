import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/notification.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/queue_provider.dart';
import 'services/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: ScalesApp()));
}

class ScalesApp extends ConsumerStatefulWidget {
  const ScalesApp({super.key});

  @override
  ConsumerState<ScalesApp> createState() => _ScalesAppState();
}

class _ScalesAppState extends ConsumerState<ScalesApp> {
  ProviderSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  void _initNotifications() {
    try {
      final service = ref.read(notificationServiceProvider);
      service.initialize().then((_) {
        _authSub = ref.listenManual(authProvider, (prev, next) {
          if (next is Authenticated) {
            service.registerToken();
            service.listenForTokenRefresh();
          } else {
            service.unregisterToken();
          }
        });
        service.onNotificationTap = (route, payload) {
          if (!mounted) return;
          _navigateFromNotification(route);
        };
        service.onQueueDataMessage = (data) {
          final venueId = data['venue_id']?.toString();
          if (venueId != null && venueId.isNotEmpty) {
            ref.invalidate(myQueueProvider(venueId));
            ref.invalidate(myQueueHistoryProvider(venueId));
          }
        };
      }).catchError((e) {
        debugPrint('[FCM] init async error: $e');
      });
    } catch (e) {
      // Firebase/FCM not available in tests or unsupported platforms — safe to ignore
      debugPrint('[FCM] init skipped: $e');
    }
  }

  void _navigateFromNotification(NotificationRoute route) {
    final router = GoRouter.of(context);
    switch (route) {
      case NotificationRoute.queue:
        router.push(RoutePaths.singerQueue);
      case NotificationRoute.songBrowser:
        router.push(RoutePaths.songBrowser);
      case NotificationRoute.singerProfile:
        router.push(RoutePaths.singerProfile);
      case NotificationRoute.leaderboard:
        router.push(RoutePaths.leaderboard);
      case NotificationRoute.checkIn:
        router.push(RoutePaths.checkIn);
      case NotificationRoute.home:
        router.push(RoutePaths.home);
      case NotificationRoute.none:
        break;
    }
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Scales',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: router,
    );
  }
}
