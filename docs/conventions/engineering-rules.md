# Engineering Rules

The mandatory rules, on one page. A pull request that breaks one is not merged.

## Trust and security

| # | Rule |
|---|---|
| S1 | The API decides every business rule. The app never calculates a price, a commission, availability or a booking status. |
| S2 | The access token lives only in secure storage. |
| S3 | Never log or send to a reporting tool: tokens, OTP codes, phone numbers, payment details. |
| S4 | No secret is compiled into the app. A value in the app is public. |
| S5 | A payment succeeds only when the API says so. The payment SDK's success callback is never trusted. |
| S6 | Ask for a device permission only when the feature needs it, with an explanation first. |

→ [security.md](security.md)

## Architecture

| # | Rule |
|---|---|
| A1 | Widget → notifier → repository → API client. A widget never calls the API or storage. |
| A2 | A feature does not import another feature's `data` or `ui`. Shared code moves to `core`. |
| A3 | `core` imports no feature. |
| A4 | Only `core/api` uses `dio`; only `core/auth` uses secure storage; only `core/config` reads environment values. |
| A5 | No new package without approval. |
| A6 | An open decision is never decided in code. |

→ [architecture.md](architecture.md), [state-management.md](state-management.md), [dependencies.md](dependencies.md)

## Data

| # | Rule |
|---|---|
| D1 | Money is never a `double`. Parse the API's string into the money type. |
| D2 | Branch on `error.code`. Never on the message, never on the HTTP status alone. |
| D3 | IDs are opaque strings. |
| D4 | Timestamps are parsed as UTC and shown in the facility's timezone. |
| D5 | A request that creates a booking or a payment order sends an `Idempotency-Key`, reused on every retry of the same user action. |
| D6 | Unknown JSON fields and unknown enum values never crash the app. |

→ [api-client.md](api-client.md)

## User interface

| # | Rule |
|---|---|
| U1 | Every screen that loads data shows loading, empty and error states. |
| U2 | No hard-coded colour, text style, spacing or radius in a widget. Use theme tokens. |
| U3 | No user-facing string in a widget. Use localisation. |
| U7 | The app's name is never typed in code, strings or tests. It comes from `appDisplayName`, generated from `app_identity.json`. The check fails otherwise. |
| U8 | Screens are assembled from `core/widgets`. A missing component is added there, with all its states, before it is used. |
| U4 | Every tappable control is at least 48 by 48 logical pixels and has a semantic label. |
| U5 | A button that starts a request is disabled while it runs. |
| U6 | Screens work at the smallest supported width and at 200% text size. |

→ [coding-standards.md](coding-standards.md), [localization-accessibility.md](localization-accessibility.md), [design](../design/README.md)

## Testing

| # | Rule |
|---|---|
| T1 | Every change to behaviour comes with tests in the same PR. |
| T2 | Every notifier has tests for success, each error it handles, and retry. |
| T3 | Tests never call a real server. |

→ [testing.md](testing.md)

## Process

| # | Rule |
|---|---|
| P1 | No direct pushes to `main` or `staging`. Everything goes through a pull request. |
| P2 | A PR needs passing CI and an approving review. |
| P3 | Commit messages and PR titles follow the commit format. |
| P4 | A change testers or users would notice adds a line to `CHANGELOG.md`. |
| P5 | Docs are updated in the same PR. |

→ [version-control.md](version-control.md), [pull-requests.md](../process/pull-requests.md)

P1 has a temporary exception during initial setup: the technical lead commits the skeleton and conventions directly.
