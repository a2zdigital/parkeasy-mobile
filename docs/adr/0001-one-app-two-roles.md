# ADR-0001: One app for customers and owners

- **Status:** Accepted
- **Date:** 2026-10-10
- **Deciders:** Technical Lead

## Context

The API lets one account hold the customer and the owner role together. Many pilot owners are individuals who also park. The team is small.

## Decision

Ship one app. After sign-in the app reads the user's roles and shows the customer area; a user with the owner role can switch to the owner area. Owner code lives in `lib/features/owner`.

## Alternatives considered

| Option | Why not |
|---|---|
| Two apps (customer, owner) | Two store listings, two release cycles and duplicated sign-in, theme and API code for a team of three |
| One codebase, two build flavours | Keeps the duplication of release work; worth revisiting if owners need a very different app |

## Consequences

- Navigation has two shells (customer, owner) and a clear switch between them.
- The owner area must not slow or clutter the customer's first experience.
- A screen must never rely on the role stored in the app: the API refuses what the user may not do, and the app handles that refusal.

## Review trigger

Owners need features that do not belong in a consumer app (attendant accounts, hardware, kiosk mode).
