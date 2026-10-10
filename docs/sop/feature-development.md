# SOP: Feature Development

From a ticket to a merged pull request.

## 1. Understand

- [ ] Read the ticket and the design for the screen.
- [ ] Find every API call it needs in the API repository's `openapi.yaml`. If one is missing or unclear, ask the API team now.
- [ ] Check [open-decisions.md](../overview/open-decisions.md). If the ticket depends on one, stop and ask.
- [ ] List the states: loading, empty, data, each error the screen must explain.

## 2. Branch

From the latest `staging`: `feat/PM-12-booking-summary`.

## 3. Build, from the inside out

| Step | Where | Test |
|---|---|---|
| Models | `features/<f>/data` | Parse the specification's example JSON |
| Repository method | `features/<f>/data` | Request sent, response mapped, error mapped |
| Notifier and state | `features/<f>/state` | Load, success, each error, retry |
| Screen | `features/<f>/ui` | Each state draws; the action calls the notifier |
| Route | `app/` router | |
| Strings | `lib/l10n/app_en.arb` | |

Use the shared components in `core/widgets` and the theme tokens. If a component is missing, add it to `core/widgets` rather than styling one screen by hand.

## 4. Check

```bash
dart run tool/check.dart
```

Then by hand: Android and iOS · small screen · 200% text · dark mode · aeroplane mode · back during a request · double-tap on the main button.

## 5. Document

- `CHANGELOG.md` if a tester would notice.
- Configuration inventory, conventions or open decisions if they changed.

## 6. Pull request

Follow [pull-requests.md](../process/pull-requests.md). Attach screenshots of every state.

## 7. After merge

Delete the branch. Move the ticket. Confirm the change in the next tester build.
