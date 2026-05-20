# Scales White-Label Venue Branding System

One Flutter codebase. N distinct app store listings. Each venue gets its own colors, typography, logo, splash, feature flags, Firebase project, and app identity.

## Quick Start

Add a new venue in three steps:

```bash
# 1. Create venue YAML + place SVG assets in white_label/branding_assets/{venue_id}/
# 2. Validate and generate everything:
python3 white_label/scripts/onboard_venue.py myvenue

# 3. Build:
flutter pub get
flutter build apk --release
```

## What's Already Shipped

- `lib/core/theme/` — Runtime theming via `theme_provider.dart` (Hive-cached, backend-fetched)
- `lib/generated/venue_config.dart` — Build-time constants (tree-shakes disabled features)

## What's In This System

| Component | Description |
|-----------|-------------|
| **Venue YAML** | Per-venue config in `white_label/venues/{id}.yaml` — colors, assets, bundle IDs, feature flags, Firebase, store metadata |
| **Code Generator** | `scripts/generate_venue.py` (or `.dart`) → `lib/generated/venue_config.dart` |
| **Icon Generator** | `scripts/generate_icons.py` — ImageMagick → Android mipmaps + iOS AppIcon.appiconset |
| **Splash Generator** | `scripts/generate_splash.py` → `flutter_native_splash.yaml` |
| **Fastlane Generator** | `scripts/generate_fastlane.py` → Play Store / App Store listing metadata |
| **Firebase Onboarding** | `scripts/firebase_onboard.py` — One Firebase project per venue, app registration |
| **Master Onboarding** | `scripts/onboard_venue.py` — Single command: validate → generate → prepare |
| **CI/CD** | `.github/workflows/build_venue.yml` + `dispatch_builds.yml` — Matrix builds across all venues |

## Directory Structure

```
white_label/
├── venues/                      # Per-venue YAML configs
│   ├── example.yaml
│   └── bluenote.yaml
├── branding_assets/             # Venue SVGs, logos, splash art
│   └── {venue_id}/
│       ├── logo.svg
│       ├── splash.svg
│       ├── icon_fg.svg
│       └── icon_bg.svg
├── scripts/
│   ├── generate_venue.py        # YAML → Dart build constants
│   ├── generate_venue.dart      # Same, Dart-native for minimal-CI environments
│   ├── generate_icons.py        # SVG → Android/iOS PNG icon packs
│   ├── generate_splash.py       # YAML → flutter_native_splash.yaml
│   ├── generate_fastlane.py     # Templates → Play Store / App Store metadata
│   ├── onboard_venue.py         # Master: validate → all generators → summary
│   └── firebase_onboard.py    # Firebase project + app registration (requires CLI login)
├── templates/
│   ├── android/                 # AndroidManifest.xml, strings.xml Mustache templates
│   ├── ios/                     # Info.plist template
│   └── app_store/               # Google Play + Apple App Store listing templates
├── ci/
│   ├── build_venue.yml          # Reusable GitHub Actions workflow
│   └── dispatch_builds.yml      # Matrix dispatch across all venues
└── DESIGN.md                    # Full architecture document
```

## Venue YAML Schema

```yaml
id: "myvenue"                        # kebab-case identifier
name: "My Venue"
legal_name: "My Venue LLC"
bundle:
  android_id: "com.myvenue.scales"
  ios_id: "com.myvenue.scales"
colors:
  primary: "#3B82F6"
  secondary: "#1E3A8A"
  background: "#F8FAFC"
  surface: "#FFFFFF"
  error: "#EF4444"
typography:
  font_family: "Inter"
  heading_weight: 700
  body_weight: 400
assets:
  logo_svg: "white_label/branding_assets/myvenue/logo.svg"
  splash_svg: "white_label/branding_assets/myvenue/splash.svg"
  icon_foreground_svg: "white_label/branding_assets/myvenue/icon_fg.svg"
  icon_background_svg: "white_label/branding_assets/myvenue/icon_bg.svg"
features:
  enabled:
    - song_browser
    - queue_status
    - merch_store
    - profile
    - notifications
    - tipping
  disabled:
    - loyalty_program
firebase:
  project_id: "myvenue-scales-prod"
  android_config: ".firebase/myvenue/android.json"
  ios_config: ".firebase/myvenue/ios.json"
stores:
  google_play:
    category: "ENTERTAINMENT"
    content_rating: "Teen"
  apple_app_store:
    category: "Music"
    content_rating: "12+"
```

## Build-time vs Runtime Theming

| Aspect | Build-time (this system) | Runtime (existing) |
|--------|-------------------------|-------------------|
| App name | Baked into AndroidManifest/Info.plist | N/A |
| Bundle ID | Baked into Gradle/Xcode | N/A |
| App icon | Rasterized PNGs at build time | N/A |
| Splash screen | OS-level drawable, before Flutter init | N/A |
| Colors/fonts | Static Dart constants for tree-shaking | Fetched from API, cached in Hive |
| Feature flags | Compiler tree-shakes disabled features | Fallback if build-time unavailable |

## Validation Rules

`onboard_venue.py` enforces:

1. YAML schema completeness (required keys present)
2. Bundle ID format (reverse-DNS)
3. Color hex validity (6 or 8-char hex)
4. No duplicate feature in enabled + disabled
5. Feature flags reference known features only
6. Asset file existence (warning, not error — assets may come later)

## CI/CD

### Build a Single Venue

Triggered by `.github/workflows/build_venue.yml` (reusable workflow):

- Installs Flutter + Python dependencies
- Runs `onboard_venue.py` for venue ID
- Builds APK (split per ABI), AAB, and iOS archive
- Uploads artifacts

### Build All Venues

`.github/workflows/dispatch_builds.yml` accepts:

```
venue_ids: bluenote,example,newvenue
```

or `all` to discover every YAML in `white_label/venues/`.

Runs up to 3 parallel builds via matrix strategy.

## Firebase Onboarding

Requires `firebase` and `gcloud` CLI authenticated:

```bash
export GCLOUD_PROJECT_PARENT="folders/12345"  # optional
python3 white_label/scripts/firebase_onboard.py bluenote --dry-run
python3 white_label/scripts/firebase_onboard.py bluenote
```

Creates:
- New Firebase project in Google Cloud
- Enabled APIs (Analytics, Crashlytics, FCM, Auth)
- Android + iOS app registrations
- Config download instructions (manual step, token-limited CLI)

**Why one Firebase project per venue?** Data isolation. Each venue sees only their analytics, crash reports, and push tokens. No cross-venue leakage risk.

## Security

- `white_label/scripts/` has write access to Android/iOS source trees. Run only in CI or trusted local environments.
- Firebase service account JSONs are **never** committed. They live in `.gitignore`-protected `.firebase/`.
- Venue YAMLs contain legal names and bundle IDs. Treat as semi-sensitive; avoid public forks.

## Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| Python 3.11+ | Scripts | System package manager |
| `pyyaml` | YAML parsing | `pip install pyyaml` |
| ImageMagick (`convert`) | SVG → PNG rasterization | `apt-get install imagemagick` |
| `firebase` CLI | Firebase project management | `npm install -g firebase-tools` |
| `gcloud` CLI | Google Cloud API enablement | [Google Cloud SDK](https://cloud.google.com/sdk) |
| `flutter_native_splash` pub package | Splash screen generation | Already in `pubspec.yaml` |

## See Also

- `DESIGN.md` — Full architecture document with trade-offs, decisions, and future extensions
- `docs/ARCHITECTURE.md` — Core Flutter app architecture (parent task)
