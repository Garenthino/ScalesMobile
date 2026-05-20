# ScalesMobile

Flutter-based mobile applications for the Scales karaoke ecosystem.

## Overview

ScalesMobile provides the complete mobile experience for karaoke singers, venue staff, and platform administrators across iOS and Android platforms.

## Repositories in Scales Ecosystem

| Repository | Purpose |
|------------|---------|
| **ScalesMobile** | Flutter mobile apps (singers, venue staff, admin) |
| [ScalesInfrastructure](https://github.com/Garenthino/ScalesInfrastructure) | Backend, API, real-time services, web portal |
| DragonHost2-Hermes | Windows-based KJ software for venue hosting |

## Project Structure

```
ScalesMobile/
├── apps/
│   ├── singer/           # Singer-facing app (song browse, queue, favorites)
│   ├── venue_staff/      # Venue staff app (check-in, queue management)
│   └── admin/            # Platform admin app (analytics, user management)
├── packages/
│   ├── core/             # Shared business logic, API clients, models
│   ├── ui/               # Shared UI components, themes, widgets
│   └── sync/             # Offline-first sync engine (CRDTs)
├── docs/                 # Architecture Decision Records, API docs
└── tools/                # Build scripts, configuration generators
```

## Technology Stack

- **Framework**: Flutter 3.x with Dart 3
- **State Management**: Riverpod
- **Offline Sync**: SQLite + CRDT-based sync engine
- **Real-time**: WebSocket client
- **Auth**: OAuth 2.0 + custom token refresh

## Quick Start

```bash
# Clone and setup
git clone https://github.com/Garenthino/ScalesMobile.git
cd ScalesMobile
flutter doctor
flutter pub get

# Run specific app
cd apps/singer && flutter run
```

## Design Documents

See [ScalesInfrastructure/docs/](https://github.com/Garenthino/ScalesInfrastructure/tree/main/docs) for system architecture and cross-repository specifications.

## License

MIT License - see LICENSE file
