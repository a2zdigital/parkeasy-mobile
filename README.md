# ParkEasy Mobile

The Flutter app for ParkEasy, a parking marketplace: customers find and book parking; owners list facilities and manage bookings. One app serves both roles. Android and iOS.

The app talks to the ParkEasy API (separate repository). The API contract is its `docs/api/openapi.yaml`.

## Quick start

```bash
flutter pub get
```

```bash
dart run tool/check.dart
```

The last command formats, analyses and tests; it must pass before every push.

## Documentation

Start at [docs/README.md](docs/README.md).

> **Status:** foundation and sign-in are built. Search, booking, payment and the owner area are not.

Copy `env/local.example.json` to `env/local.json` first, and run with `flutter run --dart-define-from-file=env/local.json`.
