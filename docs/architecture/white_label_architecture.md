# Scales Mobile — Flutter Architecture

## Overview
Single-codebase Flutter application for Android + iOS that serves both singers (patrons) and venue-branded white-label deployments. Offline-first philosophy with real-time sync.

## Architecture: Feature-First Clean Architecture

```
lib/
├── app/                    # App entry point, router
├── core/                   # Cross-cutting concerns
│   ├── constants/          # Strings, endpoints, defaults
│   ├── theme/              # White-label theme engine
│   └── utils/              # Extensions, helpers
├── data/                   # Data layer
│   ├── api/                # REST/WebSocket clients
│   ├── local/              # Hive boxes, SQLite
│   └── repositories/       # Repository implementations
├── domain/                 # Pure domain
│   ├── models/             # Serializable entities
│   ├── providers/          # Riverpod providers
│   └── services/           # Pure business logic
├── features/               # Vertical slices
│   ├── auth/
│   ├── venue_discovery/
│   ├── song_browser/
│   ├── queue_status/
│   ├── profile/
│   ├── merch_store/
│   └── notifications/
└── shared/                 # Reusable widgets & extensions
```

## State Management: Riverpod 2.x + Freezed
- Compile-time provider safety with `@riverpod` codegen
- AsyncValue<T> for load/error/success states
- StateNotifier for complex feature state machines
- Freezed for immutable copyWith patterns

## Offline Strategy
| Layer | Technology | Purpose |
|-------|-----------|---------|
| Lightweight cache | Hive | Theme config, user profile, song catalog |
| Structured data | SQLite (sqflite) | Queue history, orders, offline song requests |
| Request queue | Isar | Persistent offline write queue with retry |
| Image cache | flutter_cache_manager | Album art, venue logos |

## Real-Time Sync
| Transport | Package | Usage |
|-----------|---------|-------|
| WebSocket | web_socket_channel | Queue position, live updates |
| Push | firebase_messaging | Show start alerts, queue notifications |
| Background sync | workmanager/android_alarm_manager | Batch-sync on reconnect |

## Venue Discovery Engine
- QR scan: `mobile_scanner`
- Manual entry: numeric venue code
- GPS (opt-in): `geolocator` → nearest venue API
- NFC: optional tap-to-join at supported venues

## Core Dependencies
```yaml
# State & Architecture
flutter_riverpod: ^2.4.0
riverpod_annotation: ^2.2.0
freezed_annotation: ^2.4.0
dio: ^5.3.0
retrofit: ^4.0.0

# Offline / Local
hive_flutter: ^1.1.0
isar_flutter_libs: ^3.1.0
sqflite: ^2.3.0
connectivity_plus: ^5.0.0

# Real-Time / Push
web_socket_channel: ^2.4.0
firebase_messaging: ^14.7.0
firebase_core: ^2.24.0

# UI / Discovery
mobile_scanner: ^3.5.0
geolocator: ^10.1.0
flutter_svg: ^2.0.0
shimmer: ^3.0.0
cached_network_image: ^3.3.0

# Commerce / Auth
flutter_stripe: ^9.5.0
google_sign_in: ^6.1.0
sign_in_with_apple: ^5.0.0

# Utilities
json_annotation: ^4.8.0
logger: ^2.0.0
flutter_dotenv: ^5.1.0
```

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  freezed: ^2.4.0
  retrofit_generator: ^8.0.0
  json_serializable: ^6.7.0
  mockito: ^5.4.0
  flutter_test / integration_test

## White-Label Build Pipeline

1. Base App
   - Contains all features, screens, and integration logic.
   - Theme defaults to Scales brand.

2. Venue Config YAML
   ```yaml
   name: "The Blue Note"
   primary_color: "#3B82F6"
   splash_screen: "assets/branding/bluenote/splash.jpg"
   enabled_features: [song_browser, queue_status, merch_store]
   ```

3. Build Variants
   - `flutter run --flavor default`
   - `flutter build apk --flavor bluenote`
   - Uses `flutter_flavorizr` + CI script to inject config.

4. Dynamic Theming
   - On first launch, fetch venue config from backend.
   - Cache in Hive; apply before first frame.

## Navigation: GoRouter
- Deep linking support for venue invites (`scales://join?code=XYZ`)
- Route guards for auth-required flows
- URL-based state for Merch Store checkout

## Testing Strategy
| Level | Tool | Target |
|-------|------|--------|
| Unit | flutter_test + mockito | Providers, repositories, services |
| Widget | widget_test | Screen widgets, forms, validation |
| Integration | integration_test | Offline→online sync, checkout flow |

## Security
- API token stored in `flutter_secure_storage`
- HTTPS-only; certificate pinning via `dio` interceptor
- Stripe: PCI compliant via native SDKs
- No PII in local logs; use obfuscated `Logger`

## Environment Configuration
| File | Purpose |
|------|---------|
| `.env.dev` | Local backend, debug logging |
| `.env.staging` | Staging API, verbose analytics |
| `.env.prod` | Production, minimal logging |

## Background Sync
- `workmanager` (Android): periodic sync every 15 min
- `bg_fetch` (iOS): native background fetch
- Queue requests stored in Isar; retry with exponential backoff

