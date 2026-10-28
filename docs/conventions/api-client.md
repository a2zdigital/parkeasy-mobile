# Calling the API

The contract is `docs/api/openapi.yaml` in the API repository, with a guided tour in its `docs/api/getting-started.md`. This page says how the app implements the client side. When they disagree, the OpenAPI file is right.

> **Status:** **Implemented**: `ApiClient`, `ApiException`, error codes, pagination types, idempotency keys, and the central handling of a refused token. Booking creation is the worked example of idempotency (`CreateBookingNotifier`): the key is kept while the outcome is unknown and dropped on a definite answer or when the request changes. **Planned:** automatic single retry of `GET`s, the force-update and suspended screens.

## One client

Only `lib/core/api` uses `dio`. Features call repositories; repositories call `ApiClient`.

`ApiClient` adds to every request:

| Header | Value |
|---|---|
| `Accept` | `application/json` |
| `Authorization` | `Bearer <token>` when signed in |
| `X-App-Version`, `X-App-Platform` | From the build |
| `X-Request-Id` | Not sent; the server's value is read from the response and attached to errors |

Timeouts: 10 seconds to connect, 20 seconds to receive.

## The envelope

Success is `{ "data": …, "meta": … }`; failure is `{ "error": { "code", "message", "details", "request_id" } }`. `ApiClient` unwraps `data` and turns every failure into one exception type:

| `ApiException` field | From |
|---|---|
| `code` | `error.code`, mapped to the `ApiErrorCode` enum; an unrecognised code becomes `unknown` |
| `message` | `error.message`, for display only when the app has no better text |
| `fieldErrors` | `error.details` on `VALIDATION_FAILED` |
| `requestId` | `error.request_id` |
| `status` | HTTP status |

Connection failures, timeouts and non-JSON responses become `ApiException` too, with the codes `network`, `timeout` and `unknown`. Only a connection failure is reported as offline; an unknown transport failure or certificate error is not assumed to be a connectivity problem. **Features never see a `DioException`.**

## Errors every screen gets for free

Handled once, centrally:

| Code | Behaviour |
|---|---|
| `UNAUTHENTICATED` | Clear the session, go to sign-in |
| `ACCOUNT_SUSPENDED` | Blocking screen |
| `APP_UPDATE_REQUIRED` | Force-update screen |
| `RATE_LIMITED` | Message with the wait from `Retry-After` |
| `network`, `timeout`, `SERVICE_UNAVAILABLE`, `INTERNAL_ERROR` | The standard "Try again" state, showing the request ID |

A feature handles only the codes that mean something on its screen (`SLOT_UNAVAILABLE`, `QUOTE_EXPIRED`, `OTP_INVALID`…), and always by `code`.

## Models

- `freezed` + `json_serializable`, in the feature's `data` folder.
- Unknown fields are ignored. An unknown enum value maps to an `unknown` member, never an exception: the API may add a status before the app knows it.
- A field the API documents as nullable is nullable in Dart; nothing else is.

## Money

The API sends `"80.00"` with a `currency`. Parse it into `Money` (`core/money`, built on the `decimal` package). Never `double.parse`. The app formats money; it does not add, multiply or round amounts to produce a price. The total always comes from the quote or the booking.

## Time

- Parse timestamps as UTC. Send them as UTC ISO 8601 with `Z`.
- Show booking times in the **facility's** `timezone`, not the phone's, through `FacilityTime` (`lib/core/time`). It knows India's zone; any other zone is shown as UTC and labelled so, until a time-zone database is added.
- Countdowns (payment and approval deadlines) are computed from the server's deadline, and the screen refreshes from the API when one reaches zero.

## Pagination

Lists return `meta.next_cursor` and `meta.has_more`; pass `cursor` and `per_page`. Facility search is ordered by distance and uses `page`. One shared paginated-list notifier in `core` serves both.

## Idempotency

`POST /bookings` and `POST /bookings/{id}/payment-orders` need an `Idempotency-Key`.

1. Generate a UUID when the user presses the button.
2. Reuse **the same key** for every retry of that press: timeout, lost network, app resumed.
3. A new press after a definite answer gets a new key.
4. `REQUEST_IN_PROGRESS` means the first attempt is still running: wait and retry with the same key.

## Retries

- `GET` requests may be retried automatically once on a network failure.
- Other requests are retried only by the user, and only with the same idempotency key where one applies.

## Payments

After the payment window closes, its result is never taken as proof. `PaymentNotifier` asks `GET /bookings/{id}/payment` every two seconds: for up to a minute when the window reported success, once when it was closed or reported failure. Only the API's answer confirms a booking. If the API has not confirmed in time the screen says "still confirming" and offers no retry, because a second payment could charge the customer twice.

The provider's SDK is used only in `lib/core/payment/razorpay_checkout_launcher.dart`, behind the `CheckoutLauncher` interface; tests replace it. On a server running the simulated provider (and with `ENABLE_PAYMENT_SIMULATION` on) the screen offers "simulate success" and "simulate failure" instead of opening a window.

## A new API call

1. Find it in `openapi.yaml`. If it is not there, ask the API team; do not guess a shape.
2. Add the model and the repository method.
3. Add a repository test with the JSON from the specification's example.

Explore resolves a typed place through `GET /places/search?query=` and then continues to use `GET /parking-lots` with the selected `lat` and `lng`; the mobile app never calls Google Places directly.
