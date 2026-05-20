# Scales Mobile

Singer-facing mobile app for the **Scales** karaoke platform.

Built with Flutter + Riverpod + GoRouter.

## Architecture

The project follows clean / layered architecture:

```
lib/
├── config/            # router, environment, providers
├── core/              # constants, theme, utilities, widgets
├── data/              # datasources, models, repositories
├── domain/            # entities, repositories, usecases
└── presentation/      # screens + providers (Riverpod Notifiers)
```

## Setup

1. Install Flutter (channel `stable`, >=3.44).
2. Clone this repo.
3. Run `flutter pub get`.
4. Start a local Android emulator or web target.
5. `flutter run`

## Run Tests

```bash
flutter analyze
flutter test
```

## Code Generation

We use `build_runner` for Freezed / JSON models. When Sprint 1 adds model classes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Project Info

- Part of Scales Phase 2 MVP (parent: Sprint 0).
- Target: Android + iOS + Web.
- State: `flutter_riverpod` (v3) with sealed (`dart:`) data classes as placeholders.
- Routing: `go_router`.
- Networking: `dio` + `web_socket_channel`.
- Local storage: `shared_preferences` (Secure Storage planned Sprint 1).
