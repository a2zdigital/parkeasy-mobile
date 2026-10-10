# Changelog

What changed for the people who use or test the app. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Rules: [docs/process/changelog.md](docs/process/changelog.md).

## [Unreleased]

### Added
- **project:** Flutter project for Android and iOS (`com.swanlabstechnologies.parkeasy`).
- **docs:** Project overview, open decisions, architecture decision records, engineering conventions, process guides and onboarding.
- **ci:** GitHub Actions workflow: PR title, format, analysis and tests.
- **design:** Design system: principles, tokens with checked contrast, components, UX conventions, screen list and review notes.
- **owner:** Owner area: apply to become an owner; see bookings at your facilities; approve or reject requests; check customers in and out; record payment taken at the facility; see facilities and earnings.
- **activity:** Notifications with an unread badge; mark read; open the booking a notification is about.
- **payment:** Pay for a booking online with Razorpay. The booking is confirmed only when the server confirms the payment. Test servers offer a simulated payment instead.
- **booking:** Review and book a space (pay at the facility or online), see the booking with its status and reference, cancel it, and list your bookings.
- **explore:** Find facilities near the city centre, filter by vehicle type, open a facility, and see the price and availability for a chosen time.
- **design:** Inter is bundled as the app's typeface.
- **auth:** Sign in with a phone number and an SMS code, give a name on first sign-in, stay signed in, sign out.
- **core:** Theme tokens, shared components, configuration per environment, API client, secure token storage, routing with an access policy.
- **security:** No keys in the repository: ignore rules for key and signing files, a secret scanner in the check, Android backups off, plain HTTP only in debug builds.
- **core:** Data model: money, timestamps, error codes and every API model, tolerant of unknown fields and values.
- **design:** Placeholder brand images under fixed names in `assets/brand/`.
- **project:** The app's display name has a single source (`app_identity.json`); the check fails if the name is typed anywhere in code.
