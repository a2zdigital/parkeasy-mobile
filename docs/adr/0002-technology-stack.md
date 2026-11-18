# ADR-0002: Technology stack

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Technical Lead

## Decision

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter, stable channel, version pinned in CI | One codebase for Android and iOS |
| State and dependency injection | Riverpod (`flutter_riverpod`), providers written by hand | Compile-time safety, testable without a widget tree, no `BuildContext` needed for logic |
| Navigation | `go_router` | Declarative routes, redirects for sign-in, deep links later |
| HTTP | `dio` | Interceptors for the token, request ID and error mapping |
| Models | `freezed` + `json_serializable` | Immutable models and unions without hand-written boilerplate |
| Token storage | `flutter_secure_storage` | Keychain and Keystore |
| Decimal arithmetic | `decimal` | Money is never a `double` |
| Localisation | `flutter_localizations` + `intl` (ARB files) | Built into Flutter |
| Payments | `razorpay_flutter`, used only behind `CheckoutLauncher` in `lib/core/payment` | The API's payment provider |
| Files | `file_picker`, behind `FilePickerService` in `lib/core/files` | Owner documents and facility photos |
| Device location | `geolocator`, behind `LocationService` in `lib/core/location` | "Use my location" in Explore; foreground only |
| Maps | `flutter_map` with OpenStreetMap tiles (`latlong2` for its points), behind `pickLocationOnMap` in `lib/core/maps` | Owners place their facility's pin. Follows the OSM tile usage policy: identifying User-Agent, max zoom 19, on-device caching, no prefetching, attribution always shown. Heavy production traffic needs a commercial OSM-based tile provider (switch the URL in `mapTileLayerProvider`). |
| QR codes | `qr_flutter` (show), `mobile_scanner` (scan, behind `QrScanner` in `lib/core/scanning`) | Gate check-in |
| Push | `firebase_core`, `firebase_messaging`, behind `PushMessaging` in `lib/core/push` | The API sends through FCM; off when the Firebase files are absent ([firebase-setup.md](../sop/firebase-setup.md)) |
| Tests | `flutter_test`, `mocktail` | No code generation for mocks |

Packages are added when the first feature needs them, not in advance. Each addition follows [dependencies.md](../conventions/dependencies.md).

## Alternatives considered

| Option | Why not |
|---|---|
| Bloc | Sound, but more ceremony per feature for a small team |
| Provider, GetX | Provider is superseded by Riverpod; GetX mixes concerns and is hard to test |
| `http` package | No interceptors; they would be rewritten by hand |
| Generated API client from OpenAPI | Attractive, but generated code quality for Dart varies; revisit once the API contract is stable |

## Consequences

- Code generation (`build_runner`) is part of the workflow. Generated files are not committed: they are produced locally and in CI, and are git-ignored.
- Riverpod's code generator is not used: a hand-written `Notifier` is a few lines, and one generator (for models) is enough to keep in step with Flutter releases.
- Everyone learns Riverpod's rules in [state-management.md](../conventions/state-management.md).

## Review trigger

A chosen package is abandoned, or the OpenAPI contract is stable enough to generate the client.
