# Open Decisions

A decision that is not made yet. **Never decide one in code.** If a ticket depends on one, stop and ask the technical lead. When one is decided, record it here, and in an ADR if it is expensive to reverse.

| ID | Decision | Needed for | Status |
|---|---|---|---|
| MD-01 | Final logo and app icon artwork | Launch screen, store listing | Open; placeholders are in `assets/brand/`. Save the real images under the names in [brand-assets.md](../design/brand-assets.md) |
| MD-02 | Map provider (Google Maps, Mapbox, or list-only first) and who owns the key and its cost | Search | Open |
| MD-03 | Languages after English (Kannada, Hindi) | Text, layout | Open; all text goes through localisation from day one |
| MD-04 | Minimum Android and iOS versions | Build settings, packages | Open; working assumption Android 7 (API 24), iOS 15 |
| MD-05 | Crash and error reporting (Firebase Crashlytics or Sentry) | Supporting testers and the pilot | Open |
| MD-06 | How test builds reach testers (Firebase App Distribution, TestFlight, Play internal testing) | QA | Open |
| MD-07 | Separate staging app ID so staging and production install side by side | Release | Open; see ADR-0004 |
| MD-08 | Push notifications (FCM) | Notifications | Open; blocked until the API has device-token registration |
| MD-09 | Play Store and App Store accounts, signing keys and who holds them | Release | Open |
| MD-10 | Behaviour without a network (cached bookings to show at the gate) | Bookings | Open |
| MD-11 | Analytics: whether, which tool, and what consent is needed | Privacy policy | Open |

## Decided

| ID | Decision | Where |
|---|---|---|
| — | Application ID `com.swanlabstechnologies.parkeasy` | Project settings |
| — | One app for both roles | [ADR-0001](../adr/0001-one-app-two-roles.md) |
| — | Technology stack | [ADR-0002](../adr/0002-technology-stack.md) |
| — | Folder structure | [ADR-0003](../adr/0003-feature-first-structure.md) |
| — | Colours, typography, spacing, components, UX conventions | [design/](../design/README.md) |
| — | Light theme only in the first version | [design/principles.md](../design/principles.md) |
| — | The app's display name has one source, `app_identity.json` | [design/README.md](../design/README.md) |
