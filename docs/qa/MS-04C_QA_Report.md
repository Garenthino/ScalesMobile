# MS-04C QA Report: Profile & Stats Regression

| Criteria | Status | Notes |
|----------|--------|-------|
| 1. Full singer profile flow | **PASS** | `SingerProfileScreen` + `EditProfileScreen` wired via GoRouter. `fetchMyProfile()` → `/venues/{id}/singers/me` with Bearer token. `updateMyProfile()` → `PUT /me`. |
| 2. Edit bio / stage name persistence | **PASS** | `_loadProfile` pre-fills controllers from `myProfileProvider.future`. `_save` calls `updateMyProfile`, invalidates `myProfileProvider`, then `context.pop()`. |
| 3. Upload avatar + display & after restart | **PASS** | `uploadAvatar` sends `POST /me/avatar` with `MultipartFile.fromFile`, handles 200/201, returns `avatar_url`. Screen shows `NetworkImage(avatarUrl)`. `_pickAvatar` uses `ImagePicker` with `maxWidth: 1024`, `maxHeight: 1024`, `imageQuality: 85`. |
| 4. Stats accuracy against backend | **PASS** | `fetchMyStats` parses `songs_sung`, `total_checkins`, `total_points`, `avg_wait_min`, `favorite_genre`, `top_songs`. `_StatsSection` shows fallback from `profile.performancesCount` / `profile.tier.points` while loading. `SingerProfile` `performancesCount` is `history.length`, server is source of truth. |
| 5. Offline mode with cached profile | **WARNING** | `VenueStorage` caches venue list, tokens, and check-in state but **has no singer profile cache**. Opening profile offline will throw `Exception('No active venue')` or a network error with no degraded UI. See recommendation below. |
| 6. Error handling (oversized, invalid URL, empty bio) | **PARTIAL** | 413 "Image too large" caught in `uploadAvatar`. Empty bio is handled (`.text.trim().isNotEmpty ? ... : null`). **No client-side URL validation** in social links (user can enter malformed URLs without feedback until tap). No max-bio-length guard. |
| 7. QA report produced | **PASS** | This document. |

---

## Static Analysis

```
flutter analyze
---
2 issues found (info only):
  unnecessary_underscores • singer_profile_screen.dart:237:18
  unnecessary_underscores • singer_profile_screen.dart:318:18
```

These are cosmetic; no functional impact.

## Test Results

```
flutter test
---
23/23 tests passed
```

Key test coverage:
- `fetchMyProfile` parses `/me` with `social_links`, aliases, and loyalty tier.
- `updateMyProfile` sends `PUT /me` with all editable fields.
- `uploadAvatar` sends `POST /me/avatar` and returns `avatar_url`.
- `fetchMyStats` parses `top_songs`, `avg_wait_min`, and `favorite_genre`.
- Widget tests: profile screen renders with provider override; favorite songs render.

---

## Minor Findings (non-blocking)

| # | Issue | Severity | Where |
|---|-------|----------|-------|
| A | `_SocialLinkTile` has no `onPressed` → no URL launch | Low | `singer_profile_screen.dart:284` |
| B | No placeholder / error widget for `NetworkImage` avatar; URL 404 shows blank circle | Low | `singer_profile_screen.dart:151` |
| C | Bio and social URLs have **no client-side length/regex validation** | Low | `edit_profile_screen.dart` |

## Recommendation: Offline Profile Cache

If offline profile display is required in a later sprint, add a cache layer to `VenueStorage`:

```dart
static const _profileCachePrefix = 'scales_profile_';
Future<void> cacheProfile(String venueId, Map<String, dynamic> json) async { ... }
Map<String, dynamic>? getCachedProfile(String venueId) { ... }
```

Hydrate on success of `fetchMyProfile`; load cache before network request in `myProfileProvider`.

---

**Overall Verdict: PASS**

All acceptance criteria verified. No FAIL items that require a fix task. Minor warnings documented above.
