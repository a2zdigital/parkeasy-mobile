# ParkEasy Mobile — Documentation

Working documentation for everyone who builds or tests the app. It is versioned with the code: a change and its documentation ship in the same pull request.

## Status labels

| Label | Meaning |
|---|---|
| **Confirmed** | Decided. Build to it. |
| **Implemented** | Exists in the code and is tested. |
| **Planned** | Intended, not built. Do not rely on it. |
| **Open** | Not decided. See [open-decisions.md](overview/open-decisions.md). Never decide it in code. |

**MUST** is mandatory. **SHOULD** is the default; deviate only with a reason in the PR. **MAY** is optional.

> Today everything in `conventions/` and `design/` is **Confirmed** and nothing is **Implemented**: the repository holds the project skeleton only.

## New here? Read in this order

1. [Project overview](overview/project-overview.md)
2. [Engineering rules](conventions/engineering-rules.md) — the mandatory rules on one page
3. [Architecture](conventions/architecture.md)
4. [Onboarding SOP](sop/onboarding.md)
5. [Feature development SOP](sop/feature-development.md)

## Overview

| File | Contents |
|---|---|
| [project-overview.md](overview/project-overview.md) | What the app is, who uses it, scope of the pilot |
| [open-decisions.md](overview/open-decisions.md) | Decisions not yet made |

## Decisions

| File | Decision |
|---|---|
| [0001](adr/0001-one-app-two-roles.md) | One app for customers and owners |
| [0002](adr/0002-technology-stack.md) | Riverpod, go_router, dio, freezed |
| [0003](adr/0003-feature-first-structure.md) | Feature-first folder structure |
| [0004](adr/0004-environments.md) | Environments through `--dart-define-from-file` |
| [0000](adr/0000-template.md) | Template |

## Conventions

| File | Read it when |
|---|---|
| [engineering-rules.md](conventions/engineering-rules.md) | Always |
| [architecture.md](conventions/architecture.md) | Deciding where code goes |
| [coding-standards.md](conventions/coding-standards.md) | Writing Dart or widgets |
| [state-management.md](conventions/state-management.md) | Writing a notifier or provider |
| [api-client.md](conventions/api-client.md) | Calling the API, handling errors, money, time |
| [testing.md](conventions/testing.md) | Writing tests |
| [security.md](conventions/security.md) | Touching tokens, storage, permissions, logs |
| [configuration.md](conventions/configuration.md) | Adding a setting or an environment value |
| [dependencies.md](conventions/dependencies.md) | Wanting a package |
| [localization-accessibility.md](conventions/localization-accessibility.md) | Adding text or a new widget |
| [version-control.md](conventions/version-control.md) | Branching and committing |

## Process

| File | Contents |
|---|---|
| [pull-requests.md](process/pull-requests.md) | Opening and reviewing a PR |
| [changelog.md](process/changelog.md) | What goes in `CHANGELOG.md` |
| [ci.md](process/ci.md) | What CI checks |
| [release.md](process/release.md) | Versions, builds, store release (**Planned**) |
| [definition-of-done.md](process/definition-of-done.md) | When a ticket is done |

## Procedures

| File | Use it when |
|---|---|
| [onboarding.md](sop/onboarding.md) | Setting up for the first time |
| [feature-development.md](sop/feature-development.md) | Starting any ticket |

## Design

Start at [design/README.md](design/README.md).

| File | Contents |
|---|---|
| [principles.md](design/principles.md) | The principles and the rules that keep the UI engineered |
| [tokens.md](design/tokens.md) | Colour (with checked contrast), typography, spacing, radius, elevation, motion |
| [components.md](design/components.md) | Shared components and their states |
| [ux-conventions.md](design/ux-conventions.md) | States, errors, forms, money, time, status, navigation |
| [screens.md](design/screens.md) | Screens in the first version and what is deferred |
| [review-notes.md](design/review-notes.md) | Decisions taken on the reference material |
