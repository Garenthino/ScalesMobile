# ScalesMobile

> **Platform**: Flutter (iOS, Android, Web)  
> **Scope**: End-user karaoke experience — song browsing, queue management, singer profiles, social features, and white-label venue support.

## Architecture Overview

ScalesMobile is the Flutter client for the Scales Karaoke Platform. It targets three surfaces:

- **Singer App** — patrons browse songs, check in to venues, join the queue, view stats, and share performances.
- **KJ App** — venue staff manage the queue, approve requests, control rotation, and monitor analytics.
- **White Label Builder** — per-venue branded apps with custom logos, colors, and App Store listings.

## Documentation

| Document | Scope |
|---|---|
| [`docs/architecture/overview.md`](docs/architecture/overview.md) | Flutter architecture — BLoC, repository pattern, offline-first design, white-label mechanics |

## Parent Repository

All backend APIs, database schemas, and infrastructure decisions live in [`Garenthino/ScalesInfrastructure`](https://github.com/Garenthino/ScalesInfrastructure).

## License

MIT
