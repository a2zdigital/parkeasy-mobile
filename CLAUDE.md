# ParkEasy Mobile — Instructions for AI Coding Assistants

The Flutter app (Android, iOS) for ParkEasy, a parking marketplace. One app for customers and owners. It consumes the ParkEasy API, whose contract is `docs/api/openapi.yaml` in the API repository.

The same rules apply to AI-written code as to human-written code.

## Read first

| Task | Read |
|---|---|
| Any change | [docs/conventions/engineering-rules.md](docs/conventions/engineering-rules.md) |
| Where code goes | [docs/conventions/architecture.md](docs/conventions/architecture.md) |
| Dart and Flutter style | [docs/conventions/coding-standards.md](docs/conventions/coding-standards.md) |
| State | [docs/conventions/state-management.md](docs/conventions/state-management.md) |
| Calling the API | [docs/conventions/api-client.md](docs/conventions/api-client.md) |
| Tests | [docs/conventions/testing.md](docs/conventions/testing.md) |
| Tokens, storage, permissions | [docs/conventions/security.md](docs/conventions/security.md) |
| Any screen or widget | [docs/design/README.md](docs/design/README.md) |
| A package | [docs/conventions/dependencies.md](docs/conventions/dependencies.md) |
| Commit or PR | [docs/conventions/version-control.md](docs/conventions/version-control.md), [docs/process/pull-requests.md](docs/process/pull-requests.md) |

Full index: [docs/README.md](docs/README.md).

## Hard rules

- **Never decide an open decision.** Check [docs/overview/open-decisions.md](docs/overview/open-decisions.md). If the task depends on one, stop and ask.
- Feature-first structure: `lib/app`, `lib/core`, `lib/features/<feature>/{data,state,ui}`. Propose any structural change with the resulting folder tree and wait for approval.
- A feature never imports another feature's `data` or `ui`. Shared code moves to `lib/core`.
- Widgets do not call the API or storage. Widget → state (notifier) → repository → API client.
- The server decides every business rule. The app never calculates a price, a commission or a booking status.
- Money is never a `double`. Use the money type in `lib/core/money`.
- Branch on the API's `error.code`, never on its message.
- Every screen that loads data handles loading, empty and error.
- No hard-coded colours, text styles, spacing or user-facing strings in widgets: use the theme tokens and localisation.
- Tokens only in secure storage. Never log a token, an OTP or a phone number.
- **The app's name is never typed** in code, strings, tests or widgets. Its one source is `app_identity.json`; use `appDisplayName`, and `{appName}` placeholders in localised strings. To rename: edit the JSON, run `dart run tool/app_identity.dart`. The Dart package is named `app` for the same reason.
- UI is built only from the design tokens and shared components in [docs/design](docs/design/README.md): no literal colour, size, spacing, radius or duration in a widget, every component and screen with all its states, nothing decorative, no feature the API does not have.
- Never add a package without approval.
- Do not describe something as implemented in docs unless the code exists and is tested.
- Do not silence the analyzer with `// ignore` comments.

## Commands

| Task | Command |
|---|---|
| Format, analyse and test | `dart run tool/check.dart` |
| Format | `dart format lib test tool` |
| One test file | `flutter test test/path/to/file_test.dart` |

Run `dart run tool/check.dart` before reporting work as finished.

## Every change includes

Tests · a `CHANGELOG.md` entry when users or testers would notice · updated docs · a commit message in the format `<type>(<scope>): <subject>`, with no AI attribution trailer.

## Not in version control

`_claude/` is a private, git-ignored workspace. Do not reference its contents from tracked files.
