# ADR-0003: Feature-first folder structure

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Technical Lead

## Decision

```
lib/
├── main.dart
├── app/                  # app widget, router, theme wiring
├── core/
│   ├── api/              # HTTP client, envelope and error-code parsing, idempotency keys
│   ├── auth/             # token storage, session
│   ├── config/           # environments
│   ├── money/            # decimal money type
│   ├── theme/            # colours, typography, spacing tokens
│   └── widgets/          # shared components
├── features/
│   ├── auth/             # each feature: data/, state/, ui/
│   ├── search/
│   ├── parking_lot/
│   ├── booking/
│   ├── payment/
│   ├── notifications/
│   ├── profile/
│   └── owner/            # facilities, bookings, gate, earnings
└── l10n/
test/                     # mirrors lib/
```

Rules for what goes where are in [architecture.md](../conventions/architecture.md).

## Alternatives considered

| Option | Why not |
|---|---|
| Layer-first (`models/`, `screens/`, `services/`) | Every feature is spread over the whole tree; hard to give a feature to one developer |
| Full clean architecture (domain, use cases, entities per feature) | The business rules are in the API; the extra layers would be empty pass-throughs |
| A package per feature | Overhead not justified at this size |

## Consequences

- A feature can be built and reviewed in one folder.
- Boundaries are kept by review and by the import rules in the architecture document; an automated import check is Planned.

## Review trigger

`owner/` grows large enough to split, or the app is divided into packages.
