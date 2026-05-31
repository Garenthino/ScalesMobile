# MS-06C QA Report: Gamification Regression

**Sprint:** MS-06 (Leaderboard & Achievements)
**Date:** 2026-05-31
**Tester:** qa profile
**Backend commit:** fd883d5 (ScalesMobile)
**Backend tests:** 55 passed
**Mobile tests:** 28 passed (9 repository + 9 queue + 3 achievement + 7 widget)
**Flutter analyze:** 6 info-level lints, no errors

---

## 1. Trigger Events / Points Increment -- PASS
- Check-in awards +10 points -> verified in `test_points.py::test_checkin_awards_points`
  - `POST /singers/checkin` -> response `total_points: 10`
  - `GET /singers/me/points` ledger shows amount=10, reference_type="checkin"
- Song request awards +5 points -> `test_points.py::test_request_awards_points`
- Perform (complete) awards +25 points -> `test_points.py::test_complete_awards_perform_points`
- Tip awards +amount points -> `test_points.py::test_tip_awards_points`
- `PointsLedger` table is written and `Singer.total_points` is bumped correctly.

## 2. Leaderboard Ranking Correctness -- PASS
- All-time ranks by `Singer.total_points` descending -> `test_points.py::test_leaderboard_alltime`
  - Alice (100 pts) rank 1, Bob (50 pts) rank 2
- Rank computation counts singers with `total_points >` current singer + 1.
- `songs_sung` backfilled from `QueueRequest.status == "completed"`.
- Mobile `_FakeLeaderboardRepository` renders rank cards correctly in widget test.

## 3. Achievement Unlock at Correct Thresholds -- PASS
- **first_song** (1 performed) -> unlocked after 1st completed request
- **iron_lungs** (10 performed) -> 7/10 shows locked, progress correct
- **regular** (5 check-ins) -> unlocked after 5 `CheckInSession` rows
- **big_spender** ($50 / 5000c tips) -> unlocked after 5000c in `PointsLedger`
- All achievements initially locked with progress=0
- Backend `get_achievements_for_singer()` re-evaluates on every GET and writes `SingerAchievement` rows.

## 4. Period Filters (week/month/alltime) -- PASS
- `GET /venues/{id}/leaderboard?period={week|month|alltime}`
- `alltime` ranks by `Singer.total_points` directly.
- `week/month` sums `PointsLedger.amount` within date cutoff (7/30 days).
- `test_points.py::test_leaderboard_week_month_differentiation`:
  - Old entry (+100, 10 days ago) excluded from week, included in month/alltime
  - Week score = 50, month = 150, alltime = 150
- Mobile `LeaderboardPeriod` enum maps week/month/alltime -> 3 SegmentedButton options.

## 5. Edge Cases -- PASS
- **Tied scores:** sorted by `total_points DESC, created_at ASC` -> older singer ranks first
- **Zero points:** singers with zero still appear in alltime (included in count, ranked by creation time)
- **Large leaderboard:** backend paginated (per_page up to 100), mobile `ListView.builder` lazy

## 6. Offline: Cached Achievements Render -- FAIL
- **Expected:** When no network, cached achievements render from local storage.
- **Actual:** `AchievementRepositoryImpl.fetchMyAchievements()` calls the API unconditionally. No `SharedPreferences` cache for achievements. Offline -> error state with "Retry" button.
- **Root:** `VenueStorage` caches venue config, auth tokens, and check-in state, but does **not** cache achievement data.
- **Impact:** Users lose view of their achievement progress when offline.
- **Suggested fix:** Cache the last fetched achievements JSON in SharedPreferences under a key like `scales_achievements_{venueId}` and serve from cache when the API request fails with timeout/connection error.

## 7. QA Report Produced -- DONE
- This report saved to `docs/qa/sprint_qa_report.md`.

---

## Backend Verification Details

| Command | Result |
|---------|--------|
| `pytest tests/test_points.py -xvs` | 11 passed |
| `pytest tests/test_points.py tests/test_loyalty.py tests/test_queue_core.py` | 55 passed |
| `flutter test` | 28 passed |
| `flutter analyze` | 0 errors, 6 info lints |
| `git status` | clean working tree |

## Summary

**Status: FAIL (1 criterion)**
- Criterion 6 (offline achievement cache) is **not implemented**.
- All other criteria (1-5, 7) PASS cleanly.
