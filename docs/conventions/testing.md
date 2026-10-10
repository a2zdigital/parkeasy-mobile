# Testing

## Layers

| Layer | Tests | Tool |
|---|---|---|
| Models and `core` (money, error mapping, config) | Unit tests; JSON samples from the API specification | `flutter_test` |
| Repositories | Unit tests against a fake HTTP adapter: the request sent and the model returned | `flutter_test` |
| Notifiers | Unit tests with a fake repository in a `ProviderContainer` | `flutter_test`, `mocktail` |
| Widgets and screens | Widget tests with overridden providers: each state draws, each action calls the notifier | `flutter_test` |
| Whole flows on a device | Integration tests for the critical journeys | `integration_test` (**Planned**) |

## What every change needs

| Change | Tests |
|---|---|
| A model | Parses the documented JSON; survives an unknown field and an unknown enum value |
| A repository method | Sends the right path, body and headers; maps the response; maps an error |
| A notifier | Initial load, success, every error code it handles, retry |
| A screen | Loading, empty, error and data states; the main action |
| A bug fix | A test that fails without the fix |

## Required cases for money flows

Booking and payment notifiers must also test: the idempotency key is reused on retry and replaced after success · `SLOT_UNAVAILABLE` and `QUOTE_EXPIRED` · the payment poll ending in success, failure and timeout · the button disabled while submitting.

## Rules

- Tests never reach a real server, real storage or the real clock. Inject fakes.
- A test builds its own data. Tests do not depend on order.
- Name a test by behaviour: `shows the refund note when the cancellation is refund eligible`.
- Test folders mirror `lib`.
- Golden (screenshot) tests are **Planned**, after the design system is fixed.
- A flaky test is fixed or deleted the day it is noticed, never retried into passing.

## Manual testing

Each PR that changes a screen is run on one Android and one iOS device or simulator, on a small screen and with large text. The API's QA test plan lists the server-side cases; a mobile test plan is **Planned**.
