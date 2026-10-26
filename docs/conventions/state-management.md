# State Management

Riverpod with hand-written providers ([ADR-0002](../adr/0002-technology-stack.md)). Worked examples: `SessionController`, `PhoneSignInNotifier`, `OtpNotifier`, `CompleteProfileNotifier`.

## Kinds of provider

| Need | Use |
|---|---|
| An object with no state (repository, API client) | A plain provider |
| Data loaded once for a screen | An async notifier; the state is `AsyncValue<T>` |
| A screen with user actions (form, booking flow) | A notifier with an immutable state class |
| App-wide state (session, role in use) | A notifier in `core/auth`, kept alive |

## Rules

1. **State is immutable.** Replace it; never mutate a list or a field in place.
2. **A notifier has no `BuildContext`** and imports no widgets. It can be tested with a `ProviderContainer` alone.
3. **Widgets `watch` to draw and `read` to act.** `ref.watch` in `build`; `ref.read(...notifier)` in callbacks. Never `watch` inside a callback.
4. **Side effects** (navigation, snackbars) happen in the widget through `ref.listen`, not in the notifier.
5. **Providers auto-dispose by default.** Keep one alive only with a stated reason (the session, configuration).
6. **Parameters go through provider families** (`bookingDetailsProvider(bookingId)`), not through global mutable state.
7. **One source of truth.** After a change (a booking cancelled), invalidate the providers that show it; do not patch several copies by hand.
8. **Loading and errors are state.** A notifier catches `ApiException` and exposes it; it does not let it escape to the framework.

## Shape of a screen's state

A screen that loads uses `AsyncValue<T>`, which already has loading, data and error. A screen with actions adds what it needs:

| Field | Purpose |
|---|---|
| The data | What is drawn |
| `isSubmitting` | Disables the button while a request runs |
| `failure` | The last error, as an `ApiException`, for the widget to present |
| Field errors | From `VALIDATION_FAILED` `details`, shown next to the fields |

## Retrying

- A read retries by invalidating its provider (pull to refresh, "Try again").
- Startup restoration shows secure-storage platform failures as a retryable error instead of leaving the loading state unresolved.
- A write that needs an idempotency key creates the key once per user action and keeps it in the notifier's state until that action succeeds or the user abandons it. See [api-client.md](api-client.md).

## Paged lists

A list fetched with a cursor extends `CursorListNotifier<T>` (`lib/core/state/cursor_list.dart`) and implements only `fetchPage`. It supplies first load, refresh, load more, the failure of each, and protection against late answers. Draw it with `CursorListView`. Filters are separate providers watched in `watchInputs`, so changing one starts the list again. Examples: notifications and the owner's lists.

## Time

Nothing whose result affects behaviour calls `DateTime.now()`. Read `clockProvider`, so a test can set the time.

## Testing

Every notifier has tests with a fake repository: initial load, success, each handled error, retry. See [testing.md](testing.md).
