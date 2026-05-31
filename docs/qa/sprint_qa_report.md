# MS-05C QA Report: My Queue Regression

**Commit tested:** `b831222`  
**Date:** 2026-05-31  
**QA Agent:** qa  
**Status:** PASS

---

## Test Summary

| Criterion | Result | Notes |
|-----------|--------|-------|
| 1. Singer checks in, requests song, verifies active state | PASS | `fetchMyQueueStatus` parses `SingerQueueOut` wrapper correctly. API endpoint `/venues/{venue_id}/singers/me/queue` maps to mobile `ApiEndpoints.myQueue` |
| 2. Advance queue, verify position/ETA updates | PASS | `QueueStatusItemModel.fromJson` extracts `position`, `eta_seconds`. Backend computes `eta = ((pos - 1) * avg_ms) / 1000`. UI renders `~X min` in `_ActiveItem._formatEta` |
| 3. History shows completed entries | PASS | `fetchMyQueueHistory` parses `SingerQueueHistoryOut` with `request_id`, `song_title`, `song_artist`, `status`, `played_at`, `requested_at`. Verified in tests (items with `completed` and `skipped` statuses) |
| 4. Empty state when popped | PASS | `_EmptyActiveQueueState` and `_EmptyHistoryState` rendered when `items.isEmpty`. `LayoutBuilder` + `SingleChildScrollView` with `AlwaysScrollableScrollPhysics` ensures pull-to-refresh works on empty lists |
| 5. Backend API vs mobile display spot-check | PASS | Schema field-by-field match: `request_id`, `position`, `status`, `song_title`, `song_artist`, `song_duration_ms`, `eta_seconds`, `notes`, `requested_at` on active side; `request_id`, `song_title`, `song_artist`, `genre`, `status`, `requested_at`, `played_at`, `notes` on history side |
| 6. Error: network failure, unauthorized | PASS | `DioException` caught in all repo methods, mapped to human-readable error. `api_client.dart` interceptor handles 401: clears token so auth provider can re-authenticate. `_QueueErrorState` in UI shows retry button with `ref.invalidate(...)`. `_QueueErrorState.onRetry` wired for both active and history tabs |
| 7. Flutter static analysis | PASS | `flutter analyze`: 5 info-level `unnecessary_underscores` in non-queue files (pre-existing). Queue-related (`singer_queue_screen.dart:48, 92, 165`) also info-level only — no warnings or errors |
| 8. Unit/integration tests | PASS | `flutter test`: 28/28 passed (21 parsing tests + 7 widget tests). 5 new queue-specific parsing tests: `fetchMyQueueStatus` wrapper, empty, history (completed+skipped), join, leave |
| 9. Venue-scoped endpoint wiring | PASS | `ApiEndpoints.myQueue(venueId)` and `.myQueueHistory(venueId)` both accept `venueId` parameter. `QueueRepositoryImpl` methods pass to correct venue-scoped path. No hardcoded `venue_1` in production code |
| 10. Provider invalidation on new request | PASS | `SongBrowserScreen._onRequestSong` calls `ref.invalidate(myQueueProvider(venue.id))` after successful `joinQueue`. Provider is `autoDispose`, so stale data is purged |

---

## Code Quality Findings

### Minor: Info-level linter (not blocking)
- `singer_queue_screen.dart:48`, `:92`, `:165` use `__` parameters instead of `_`. Dart lint `unnecessary_underscores` flags them. These are `separatorBuilder` and anonymous lambda parameters across the file — cosmetic, no behavioral impact.

### Verified Cross-Stack Compatibility
- **Backend** (`app/routers/singers.py`): `SingerQueueItem` schema has `request_id`, `position`, `status`, `song_title`, `song_artist`, `song_duration_ms`, `eta_seconds`, `notes`, `requested_at` — every field consumed by mobile `_ActiveItem` is present.
- **Backend** (`app/routers/singers.py`): `SingerQueueHistoryItem` schema has `request_id`, `song_title`, `song_artist`, `genre`, `status`, `requested_at`, `played_at`, `notes` — all consumed by `_HistoryItem`.
- **Mobile** (`lib/data/models/queue_request_model.dart`): Models handle null-safety gracefully with `?? ''`, `?? 'Unknown song'`, `?? 'Unknown artist'` to prevent crash on malformed API response.

---

## Architecture Assessment

| Layer | Observation | Grade |
|-------|-------------|-------|
| **Entity** | `QueueStatusItem`, `QueueHistoryItem`, `QueueHistoryResult` are clean, immutable, no leakage | A |
| **Model** | `QueueStatusItemModel.fromJson`, `QueueHistoryItemModel.fromJson` are null-safe, use `whereType<Map>()` | A |
| **Repository** | `QueueRepositoryImpl` uses `ApiEndpoints` constants, handles `DioException`, `_requireAuthToken` via `VenueStorage` | A |
| **Provider** | `myQueueProvider` and `myQueueHistoryProvider` are `autoDispose.family<..., String>` keyed on `venueId` — correct for multi-venue | A |
| **Presentation** | `SingerQueueScreen` uses `TabBarView` with `SingleTickerProviderStateMixin`, proper `dispose()`. Empty/error states handled. Pull-to-refresh wired via `RefreshIndicator`. | A |
| **Auth** | 401 interceptor clears venue token → next request triggers re-auth. `Unauthorized` returns `"Session expired. Please sign in again."` in `_errorMessage`. | A |

---

## Recommendations (Non-Blocking)
1. **Linter hygiene:** Replace `(_, __)` with `(_, _)` in `ListView.separated` `separatorBuilder` across the codebase.
2. **Widget test gap:** Add a `testWidgets` test that renders `SingerQueueScreen` with fake `myQueueProvider` / `myQueueHistoryProvider` overrides to verify TabBarView construction under each async state (loading/data/error/empty).
3. **Backend schema:** Consider returning `null` for `eta_seconds` rather than `0` when `position` is 0 or unknown, to distinguish "can't compute" from "no wait".

---

## QA Sign-off

**All acceptance criteria met. No fix tasks required.**
