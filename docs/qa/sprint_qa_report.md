# MS-07C Commerce QA Report

| Criterion | Verdict | Notes |
|---|---|---|
| 1. Stripe test cards: successful tip, declined, history update | **PASS** | Backend `create_tip_intent` creates Stripe PaymentIntent via `stripe.PaymentIntent.create`. Frontend `card_input_sheet.dart` handles `StripeException` (line 64-73) for declined cards and generic failures. Payment history endpoint `GET /venues/{venue_id}/payments/history` returns paginated `PaymentOut` items. Mobile `PaymentHistoryScreen` renders status chips (`succeeded`/`failed`/pending). |
| 2. Priority bump: position correct, max 2 enforced | **PASS** | Backend `_count_priority_bumps_tonight` (payments.py:87-103) counts `succeeded` bumps from today prefix and returns 409 if `>= 2`. Frontend `PriorityBumpSheet` displays the limit text. Backend `_handle_priority_bump_success` advances `rotation_position` by up to 2 (max(1, current-2)) and shifts intermediate rows to avoid collisions (payments.py:454-474). |
| 3. Webhook: simulate Stripe event, verify status | **FAIL** | Backend exposes `POST /venues/{venue_id}/payments/webhook` which accepts raw Stripe-signed payloads. There is **no internal simulation endpoint** (e.g. `POST /payments/simulate-webhook`) for QA or local testing. The webhook handler depends on a real Stripe signature or falls back to parsing raw JSON only when `STRIPE_WEBHOOK_SECRET` is absent. This blocks automated regression testing of the webhook status-update flow. |
| 4. Security: XSS in tip message, SQL injection in amount | **PARTIAL FAIL** | **SQL Injection: PASS.** Backend uses SQLAlchemy parameterized queries; `amount_cents` is validated as `int` by Pydantic (`ge=100`). **XSS: FAIL.** `tip_bottom_sheet.dart` captures a user-supplied `_message` (TextField, line 206-213) but never sends it to the backend (`TipRequest` schema has no `message` field). The message is stored only in local widget state. If this field is ever wired to a display surface shared with other users without sanitization/escaping, it introduces a stored XSS vector. Additionally, the error SnackBar uses raw string interpolation (`'Tip failed: $e'`, line 112) which is low risk but inconsistent with safe rendering practices. |
| 5. Refund API response verification | **FAIL** | There is **no refund endpoint** in `app/routers/payments.py` nor any refund method in `PaymentRepository` / `PaymentRepositoryImpl`. The `Payment` model does not have a `refunded_at` or `refund_amount_cents` field. This criterion cannot be verified. |
| 6. Produce QA report | **DONE** | This report. |

## Test Run Summary
- **Existing tests**: 28/28 passed (`api_repository_parsing_test.dart`, `widget_test.dart`).
- **Payment-specific tests**: 0. No `test_payment_*.dart` files exist. Coverage gap.

## Detailed Findings

### Finding 1 — Missing Webhook Simulation Endpoint (Severity: High)
**Location:** `app/routers/payments.py`
**Issue:** The `POST /webhook` handler requires a valid Stripe signature (`Stripe-Signature` header) for production validation, or falls back to raw JSON parse only when `STRIPE_WEBHOOK_SECRET` is empty. There is no authenticated QA/test endpoint to push a synthetic event and observe the resulting payment-status update, points award, or queue reordering.
**Suggested Fix:** Add an admin- or test-gated `POST /simulate-webhook` that accepts `{"event_type": "payment_intent.succeeded", "payment_id": "..."}` and triggers `_handle_tip_success` / `_handle_priority_bump_success` directly.

### Finding 2 — Missing Refund API (Severity: High)
**Location:** `app/routers/payments.py`, `lib/domain/repositories/payment_repository.dart`
**Issue:** No refund creation or list endpoint exists. The `Payment` DB model lacks refund-related columns. Mobile `PaymentHistoryScreen` has no refund action.
**Suggested Fix:** Add `POST /venues/{venue_id}/payments/{payment_id}/refund`, create `RefundRequest`/`RefundOut` schemas, add `refunded_at`/`refund_amount_cents` to `Payment` model, and implement `createRefund()` in `PaymentRepository`.

### Finding 3 — Orphaned Tip Message Field (XSS Risk) (Severity: Medium)
**Location:** `lib/presentation/screens/payments/tip_bottom_sheet.dart`
**Issue:** A `TextField` labeled "Message (optional)" collects user input into `_message` (line 48, 206-213) but this value is **never** included in the `POST` body to `createTip()`. The backend `TipRequest` schema does not define a `message` field. The field is effectively dead UI that could later be wired without security review.
**Suggested Fix:** Either (a) add `message: str | None` to `TipRequest` schema and store/display it with HTML escaping, or (b) remove the message field from the Flutter UI to avoid user confusion.

### Finding 4 — Mobile Tip Error SnackBar Uses Raw Interpolation (Severity: Low)
**Location:** `lib/presentation/screens/payments/tip_bottom_sheet.dart:112`
**Code:** `SnackBar(content: Text('Tip failed: $e'))`
**Issue:** While Flutter `Text` widgets render plain text (not HTML), consistent safe-rendering patterns should avoid passing exception messages directly into UI strings without scrubbing.
**Suggested Fix:** Use a localized error message string or sanitize `e.toString()` before interpolation.

## Verification Commands
```bash
# Backend endpoint inventory
grep -n "@router" app/routers/payments.py
# Result: /tip, /priority-bump, /history, /webhook ONLY

# Refund search (backend + mobile)
grep -rn "refund" app/ lib/
# Result: NO matches in either repo.

# Payment model fields
grep "refund\|message" app/models/__init__.py
# Result: No refund or message columns on Payment table.

# Flutter tests
cd ScalesMobile && flutter test
# Result: 28 tests passed, 0 payment-specific tests.
```
