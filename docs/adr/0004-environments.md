# ADR-0004: Environments through `--dart-define-from-file`

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Technical Lead

## Context

The app must run against a local API, staging and production. Developers work on Windows and macOS.

## Decision

One JSON file per environment in `env/` (`local.json`, `staging.json`, `production.json`), passed at build time:

```bash
flutter run --dart-define-from-file=env/local.json
```

`lib/core/config` reads the values with `String.fromEnvironment` into one typed `AppConfig`. Nothing else reads environment values. `env/local.example.json` is committed; real files are git-ignored. These files hold **no secrets**: anything compiled into an app can be extracted.

Native build flavours (a separate application ID and icon for staging) are not set up now. Whether to add them is open decision MD-07.

## Alternatives considered

| Option | Why not |
|---|---|
| Native flavours from day one | More Gradle and Xcode configuration than is useful before a staging server exists |
| `.env` file read at runtime | Adds a package and ships the file as an asset |

## Consequences

Running without the flag must fail clearly at start-up, not silently call the wrong server.

## Review trigger

Testers need staging and production installed side by side.
