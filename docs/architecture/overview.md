# Scales Mobile - Flutter App Architecture

> Venue-branded white-label karaoke/live show mobile application
> Android + iOS | Offline-first | Real-time sync

---

## 1. Project Structure

```
scales_mobile/
├── android/                          # Android platform config
├── ios/                              # iOS platform config
├── lib/
│   ├── main.dart                     # Entry point
│   ├── app.dart                      # Root App widget
│   │
│   ├── core/                         # Foundation layer
│   │   ├── constants/
│   │   │   ├── api_constants.dart
│   │   │   ├── app_theme.dart
│   │   │   └── venue_config.dart
│   │   ├── errors/
│   │   │   ├── failures.dart
│   │   │   └── exception_handlers.dart
│   │   ├── extensions/
│   │   ├── utils/
│   │   └── di/                       # Dependency injection
│   │       └── service_locator.dart
│   │
│   ├── data/                         # Data layer
│   │   ├── datasources/
│   │   │   ├── local/                # Hive, SharedPreferences
│   │   │   │   ├── hive_adapters/
│   │   │   │   ├── venue_cache.dart
│   │   │   │   ├── song_cache.dart
│   │   │   │   ├── request_queue.dart
│   │   │   │   └── user_prefs.dart
│   │   │   └── remote/               # API clients, WebSocket
│   │   │       ├── api_client.dart
│   │   │       ├── websocket_client.dart
│   │   │       └── push_service.dart
│   │   ├── models/
│   │   │   ├── song_model.dart
│   │   │   ├── venue_model.dart
│   │   │   ├── request_model.dart
│   │   │   ├── user_model.dart
│   │   │   └── theme_config.dart
│   │   └── repositories/
│   │       ├── song_repository_impl.dart
│   │       ├── venue_repository_impl.dart
│   │       └── request_repository_impl.dart
│   │
│   ├── domain/                       # Business logic
│   │   ├── entities/
│   │   │   ├── song.dart
│   │   │   ├── venue.dart
│   │   │   ├── request.dart
│   │   │   └── user.dart
│   │   ├── repositories/
│   │   │   ├── song_repository.dart
│   │   │   ├── venue_repository.dart
│   │   │   └── request_repository.dart
│   │   └── usecases/
│   │       ├── browse_songs.dart
│   │       ├── submit_request.dart
│   │       ├── join_venue.dart
│   │       └── sync_queue.dart
│   │
│   ├── presentation/                 # UI layer (Feature-based)
│   │   ├── shared/                   # Shared UI components
│   │   │   ├── widgets/
│   │   │   ├── animations/
│   │   │   └── branding/
│   │   │
│   │   ├── venue_discovery/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   ├── controllers/        # Riverpod providers
│   │   │   └── venue_discovery_module.dart
│   │   │
│   │   ├── song_browser/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   ├── controllers/
│   │   │   └── song_browser_module.dart
│   │   │
│   │   ├── queue_status/
│   │   │   ├── screens/
│   │   │   ├── controllers/
│   │   │   └── queue_status_module.dart
│   │   │
│   │   ├── profile/
│   │   │   ├── screens/
│   │   │   ├── controllers/
│   │   │   └── profile_module.dart
│   │   │
│   │   ├── merch_store/
│   │   │   ├── screens/
│   │   │   ├── controllers/
│   │   │   └── merch_store_module.dart
│   │   │
│   │   └── notifications/
│   │       ├── screens/
│   │       └── notifications_module.dart
│   │
│   └── services/                     # Application services
│       ├── connectivity_service.dart
│       ├── sync_service.dart
│       └── venue_branding_service.dart
│
├── assets/
│   ├── fonts/
│   ├── images/
│   └── branding/                     # Venue-specific assets
│       ├── default/
│       └── {venue_code}/
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml
└── white_label_config.yaml           # Build-time branding config
```

---

## 2. State Management: Riverpod 2.x

**Rationale**: Compile-time safety, testability, granular rebuild control, excellent for dependency injection.

### Provider Hierarchy

```dart
// Core providers (@riverpod)
@riverpod
ApiClient apiClient(ApiClientRef ref) => ApiClient();

@riverpod
WebSocketClient wsClient(WsClientRef ref) => WebSocketClient();

@riverpod
ConnectivityService connectivity(ConnectivityRef ref) => ConnectivityService();

// Repository providers
@riverpod
SongRepository songRepository(SongRepositoryRef ref) {
  return SongRepositoryImpl(
    remote: ref.watch(apiClientProvider),
    local: HiveSongCache(),
    connectivity: ref.watch(connectivityProvider),
  );
}

// Feature controllers (AsyncNotifier)
@riverpod
class SongBrowserController extends _$SongBrowserController {
  @override
  Future<List<Song>> build() async {
    final repo = ref.read(songRepositoryProvider);
    return repo.getCachedSongs();
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(songRepositoryProvider);
      return repo.searchSongs(query);
    });
  }
}

// Venue-scoped providers (override at join)
final currentVenueProvider = StateProvider<Venue?>((ref) => null);
final venueThemeProvider = Provider<ThemeData>((ref) {
  final venue = ref.watch(currentVenueProvider);
  return venue != null ? venue.theme.toFlutterTheme() : defaultTheme;
});
```

---

## 3. Offline-First Strategy

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   User Action   │────▶│  Request Handler  │────▶│ Local Cache │
└─────────────────┘     └──────────────────┘     └──────┬──────┘
                                                        │
                        ┌──────────────────┐            │
                        │  Success Return  │◄───────────┘
                        └──────────────────┘
                                        │
                              (background, if online)
                                        ▼
                        ┌────────────────────────┐
                        │  ┌──────────────────┐   │
                        │  │   Sync Queue     │   │
                        │  │  ┌────────────┐  │   │
                        │  │  │ Retry w/   │  │   │
                        │  │  │ backoff    │──┼───┼──▶ Remote API
                        │  │  └────────────┘  │   │
                        │  └──────────────────┘   │
                        └────────────────────────┘
```

### Hive Schema

```dart
// lib/data/datasources/local/hive_adapters/song_adapter.dart
@HiveType(typeId: 1)
class SongModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String artist;
  
  @HiveField(3)
  final String venueId;
  
  @HiveField(4)
  final DateTime cachedAt;
}

// lib/data/datasources/local/request_queue.dart
class PendingRequest extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final RequestType type; // songRequest, merchPurchase, etc.
  
  @HiveField(2)
  final Map<String, dynamic> payload;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  int retryCount = 0;
  
  @HiveField(5)
  RequestStatus status; // pending, failed, processing
}

// Indexed boxes for fast lookup
// - songs_box: indexed by venueId + query hash
// - requests_box: indexed by status
// - favorites_box: indexed by userId
```

### Sync Service

```dart
@riverpod
class SyncService extends _$SyncService {
  @override
  void build() {
    // Listen to connectivity
    ref.listen(connectivityProvider, (prev, curr) {
      if (prev?.isOffline == true && curr.isOnline) {
        _processSyncQueue();
      }
    });
  }

  Future<void> _processSyncQueue() async {
    final pending = await _queue.getPending();
    for (final request in pending) {
      try {
        await _submitToApi(request);
        await _queue.markComplete(request.id);
      } catch (e) {
        await _queue.incrementRetry(request.id);
        if (request.retryCount >= 3) {
          await _queue.markFailed(request.id);
          _notifyUser(request);
        }
      }
    }
  }
}
```

---

## 4. Real-Time Integration

### WebSocket Architecture

```dart
// lib/data/datasources/remote/websocket_client.dart
class WebSocketClient {
  static const _reconnectIntervals = [1, 2, 5, 10, 30]; // seconds
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();
  
  Stream<ServerMessage> get messages => _messageController.stream;
  Stream<ConnectionState> get connectionState => _connectionController.stream;
  
  void connect(String venueId, {String? authToken}) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://api.scales.app/ws/venue/$venueId'),
      protocols: authToken != null ? ['bearer', authToken] : null,
    );
    
    _channel!.stream.listen(
      (data) => _handleMessage(data),
      onError: _handleError,
      onDone: _handleDisconnect,
    );
    
    _connectionController.add(ConnectionState.connected);
  }
  
  void _handleMessage(dynamic data) {
    final message = ServerMessage.fromJson(jsonDecode(data));
    _messageController.add(message);
    
    // Auto-sync to local cache
    if (message is QueueUpdateMessage) {
      _updateLocalQueue(message.data);
    }
  }
}

// Message types
sealed class ServerMessage {
  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'queue_update' => QueueUpdateMessage.fromJson(json),
      'request_status' => RequestStatusMessage.fromJson(json),
      'venue_announcement' => AnnouncementMessage.fromJson(json),
      _ => UnknownMessage(),
    };
  }
}
```

### Push Notifications (Firebase)

```dart
// lib/data/datasources/remote/push_service.dart
class PushNotificationService {
  final FirebaseMessaging _messaging;
  final LocalNotificationService _local;
  
  Future<void> initialize() async {
    await _messaging.requestPermission();
    
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForeground);
    
    // Background/terminated
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    
    // Get token for venue
    final token = await _messaging.getToken();
    await _registerWithBackend(token);
  }
  
  void _handleForeground(RemoteMessage message) {
    _local.show(
      title: message.notification?.title,
      body: message.notification?.body,
      payload: message.data,
    );
    
    // Update local state via Riverpod
    ref.read(unreadNotificationsProvider.notifier).increment();
  }
}

// Top-level background handler (isolates must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Hive.initFlutter();
  // Queue critical updates for UI sync on resume
  await BackgroundSyncQueue.enqueue(message.data);
}
```

---

## 5. Venue Discovery

### QR Code Scan

```dart
// lib/presentation/venue_discovery/widgets/qr_scanner.dart
class VenueQRScanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MobileScanner(
      onDetect: (capture) {
        final code = capture.barcodes.first.rawValue;
        if (code != null && _isValidVenueCode(code)) {
          ref.read(venueDiscoveryControllerProvider.notifier)
              .joinByCode(code);
        }
      },
    );
  }
}
```

### GPS Discovery (Optional)

```dart
// lib/services/venue_discovery_service.dart
class VenueDiscoveryService {
  static const _maxRadiusMeters = 5000; // 5km
  
  Future<List<Venue>> findNearbyVenues() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return [];
    
    final position = await Geolocator.getCurrentPosition();
    
    return _api.getVenuesNear(
      lat: position.latitude,
      lng: position.longitude,
      radius: _maxRadiusMeters,
    );
  }
}
```

---

## 6. Core Screens

### Venue Discovery / Join Show

| Feature | Implementation |
|---------|---------------|
| QR Scanner | `mobile_scanner` package, with fallback to manual entry |
| Manual Entry | TextField with venue code format validation |
| Nearby Venues | Optional GPS-based list with distance sorting |
| Venue Details | Brand preview, active show status, capacity |

### Song Browser

| Feature | Implementation |
|---------|---------------|
| Search | Debounced 300ms, search as you type with Hive cache |
| Filters | Genre, decade, difficulty, popularity chips |
| Favorites | Local toggle with optimistic UI |
| Infinite Scroll | Pagination with `flutter_pagewise` |
| Offline Indicator | `connectivity_plus` badge on stale data |

### Queue Status / My Requests

| Feature | Implementation |
|---------|---------------|
| Live Position | WebSocket-driven position updates |
| ETA Calculation | Avg song duration × position ahead |
| Song Notification | Push for "your turn coming up" |
| Cancel Request | Offline queueable cancellation |

### Profile

| Feature | Implementation |
|---------|---------------|
| Stage Name | Editable, venue-scoped |
| History | Local cache with sync |
| Loyalty | Points/badges from backend |

### Merch Store

| Feature | Implementation |
|---------|---------------|
| Product Grid | Cached catalog images |
| Cart | Local storage, sync on checkout |
| Stripe Checkout | `flutter_stripe` payment sheet |
| Inventory | Real-time stock via WebSocket |

---

## 7. Payment Integration (Stripe)

```dart
// lib/presentation/merch_store/controllers/checkout_controller.dart
@riverpod
class CheckoutController extends _$CheckoutController {
  @override
  Future<Cart?> build() => ref.read(cartRepositoryProvider).getCart();
  
  Future<void> initiateCheckout() async {
    final cart = state.valueOrNull;
    if (cart == null || cart.isEmpty) return;
    
    // 1. Create payment intent on backend
    final clientSecret = await _api.createPaymentIntent(
      amount: cart.totalCents,
      currency: cart.currency,
    );
    
    // 2. Present Stripe sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: currentVenue.name,
      ),
    );
    
    // 3. Present and confirm
    await Stripe.instance.presentPaymentSheet();
    
    // 4. Confirm order
    await _api.confirmOrder(cart.id);
    await ref.read(cartRepositoryProvider).clear();
  }
}
```

**Important**: Physical merch only. No alcohol/tip integration to avoid POS liability.

---

## 8. Venue Branding System

### Theme Configuration

```dart
// lib/data/models/theme_config.dart
@JsonSerializable()
class VenueThemeConfig {
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String textColor;
  final String fontFamily;
  final Map<String, dynamic> customProperties;

  ThemeData toFlutterTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(int.parse(primaryColor)),
        secondary: Color(int.parse(secondaryColor)),
      ),
      fontFamily: fontFamily,
      // Apply custom overrides
      ...customProperties,
    );
  }
}

// Dynamic asset loading
class VenueAssetLoader {
  static Future<ImageProvider> loadLogo(String venueId) async {
    // 1. Check local cache
    final cached = await _getCachedLogo(venueId);
    if (cached != null) return FileImage(cached);
    
    // 2. Download from CDN
    final remote = await _downloadLogo(venueId);
    await _cacheLogo(venueId, remote);
    return MemoryImage(remote);
  }
}
```

### White-Label Build Pipeline

```yaml
# white_label_config.yaml
venues:
  - code: rock_bar_nyc
    name: "Rock Bar NYC"
    bundle_id: com.scales.rockbarnyc
    theme:
      primary: "#FF1744"
      secondary: "#212121"
      font: "BebasNeue"
    assets:
      logo: ./assets/branding/rock_bar/logo.png
      splash: ./assets/branding/rock_bar/splash.png
      icon_foreground: ./assets/branding/rock_bar/icon_fg.png
      icon_background: ./assets/branding/rock_bar/icon_bg.png
    
  - code: jazz_lounge_sf
    name: "SF Jazz Lounge"
    bundle_id: com.scales.jazzloungesf
    theme:
      primary: "#673AB7"
      secondary: "#FF9800"
```

```bash
# Build script
./scripts/build_white_label.sh --venue=rock_bar_nyc --env=prod
```

---

## 9. Architecture Patterns

### Clean Architecture Layers

```
Presentation (UI)  <──────>  Domain (Business)  <──────>  Data (Sources)
     │                            │                          │
  Riverpod                    Use Cases                 Repository
  Widgets                     Entities                  Models
  Controllers                 Repository                Local/Remote
     │                           Interface                   │
     └───────────────────────────────────────────────────────┘
                         Dependency Rule (inward only)
```

### Data Flow: Song Request

```
1. User taps "Request Song"
   │
   ▼
2. Controller calls UseCase submitRequest()
   │
   ▼
3. Repository handles:
   ├─ ONLINE: POST /api/requests → update local cache
   ├─ OFFLINE: Save to PendingRequest queue
   │
   ▼
4. SyncService (background):
   ├─ Retries pending requests
   ├─ Updates UI on success
   └─ Warns on permanent failure
   │
   ▼
5. WebSocket: Receive queue_update → update UI position
```

---

## 10. Testing Strategy

| Layer | Approach | Tools |
|-------|----------|-------|
| Unit | Pure functions, use cases | `flutter_test`, `mocktail` |
| Widget | Screen tests with mocked providers | `widget_test`, `golden_toolkit` |
| Integration | Full user flows | `integration_test`, Firebase Test Lab |
| E2E | Real device, real API | Manual + Firebase |

---

## 11. Security Considerations

- **API Keys**: Never hardcode. Use `--dart-define` or runtime config
- **Local Storage**: Hive is not encrypted by default → use `hive_encrypt` for PII
- **WebSocket Auth**: Token-based with expiry refresh
- **Payment**: PCI compliance via Stripe SDK (never touch raw cards)
- **Venue Isolation**: Each venue's data sandboxed by user session

---

## 12. Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Cold start | < 2s | App start to interactive |
| Song search | < 100ms | Local results, debounced remote |
| Offline latency | 0ms | All reads from Hive |
| Bundle size | < 50MB | Per-venue white-label APK |
| WebSocket reconnect | < 5s | Exponential backoff |

---

Generated for Scales Mobile v1.0 Architecture
