# Release

> **Status: Planned.** No build has been released. Store accounts, signing and tester distribution are open decisions (MD-06, MD-09). This page records what is already fixed and will be completed with the first tester build.

## Version numbers

`pubspec.yaml` holds `version: MAJOR.MINOR.PATCH+BUILD`.

| Part | Changes when |
|---|---|
| `MAJOR` | A redesign or a change users must relearn |
| `MINOR` | New capability |
| `PATCH` | Fixes only |
| `BUILD` | Every build sent to a store or to testers; always increases |

The git tag is `vMAJOR.MINOR.PATCH`.

## The app version and the API

The app sends `X-App-Version` on every request. The API can refuse versions below a minimum with `APP_UPDATE_REQUIRED`, and the app then shows a force-update screen. A release that needs a new API endpoint is not published until that API is in production.

## Outline of a release

1. PR from `staging` into `main`, with the changelog section renamed to the version.
2. Manual test pass on Android and iOS.
3. Build with the production environment file, obfuscated.
4. Upload; staged roll-out on Android.
5. Tag `main`.

## Before the first release build

- Razorpay's Android SDK needs its ProGuard rules when code shrinking is on. Add them with the release signing setup and test a release build's checkout.
- Confirm the checkout window on both platforms with test keys.

## Never

Commit a keystore, a signing certificate or a store credential. Where they are kept is part of MD-09.
