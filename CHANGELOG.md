
# Changelog

What changed for the people who use or test the app. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Rules: [docs/process/changelog.md](docs/process/changelog.md).

## [Unreleased]

### Added
- **activity:** Add horizontally scrollable activity categories, category-specific empty states, event icons, and role/type-based filtering of admin and system notifications while keeping the API-provided read state and navigation.
- **app:** Premium redesign pass: a tighter type scale, soft card shadows, a cleaner bottom bar, grouped list rows, a sliding segmented control and an initials avatar. Welcome shows three value points with Log in and Create account; Profile has an avatar header and grouped menu; Bookings and owner Bookings use a segmented switch; booking cards and details show the status beside the title, once; Earnings leads with a navy balance card; facility details groups booking and payment facts. Layouts are tested at 150% text.
- **app:** Motion that explains what changed: pages fade and rise in (Android; iOS keeps its swipe-back), the first items of a list rise in, buttons and cards respond to a press, the check-in code and payment results are revealed, booking status changes cross-fade, earnings totals count up, opening sections grow smoothly, and a map pin drops into place. All of it turns off when the phone asks for reduced motion.
- **app:** Empty and error states show their icon in a soft tinted circle, the same on every screen.
- **owner:** Set a facility's exact location on an OpenStreetMap map: drag the pin or tap the map, confirm, and the latitude and longitude follow. The map opens at the address found for it (adds `flutter_map`, `latlong2`).
- **owner:** New facility: Google Maps is searched (through the API's place search) as the owner types the name and address, after a short pause. One place with the facility's own name fills the address, PIN and coordinates for the owner to check, and can be changed; several places are listed to choose from. The manual options (set on map, find from address, use my current location, adjust coordinates) open only when nothing matches, the search fails, or the owner asks. The location is never filled in or guessed on save, and the map's general-area pin must be moved before it can be confirmed. All fields show in one scrolling form with section headings.
- **owner:** Profile > Documents: add verification documents any time; none is required to apply or to list a facility.
- **owner:** Link a parking licence to one of your facilities when uploading it, and see the linked facility beside the document.
- **explore:** "Use my location" searches for parking around the phone (adds `geolocator`; location is asked for only when tapped).
- **booking:** The check-in code is also shown as a QR code (adds `qr_flutter`).
- **owner:** Scan the customer's QR code to check them in (adds `mobile_scanner`).
- **notifications:** Push notifications through Firebase: the device registers with the API after sign-in and is removed at sign-out; tapping a notification opens its screen. Off until the Firebase files are added (adds `firebase_core`, `firebase_messaging`).
- **booking:** A confirmed booking shows its gate check-in code (as text; a scannable QR code waits on the QR package approval) and, at facilities with numbered bays, the bay.
- **owner:** Check a customer in by typing their code (on a confirmed booking: Check in with a code).
- **owner:** Numbered bays: switch a vehicle type to numbered bays from a range or a list of labels, add bays, and take bays out of use or delete them. Capacity follows the bays in use.
- **support:** Help and support in Profile: open a ticket, follow the conversation and reply.
- **booking:** Rate a completed booking (1 to 5 stars, optional comment); facilities show their score.
- **owner:** Upload identity, business and property documents with the owner application, and add, reorder and remove facility photos (adds the `file_picker` package).
- **activity:** Notifications about refunds, failed payments, facility decisions and payouts open the right screen: the booking, the facility, or Earnings.
- **owner:** Delete a draft facility, or pause and resume bookings at a live one.
- **owner:** Clearing a rate in the spaces form now stops offering it.
- **owner:** The earnings screen lists your payouts.
- **explore:** Facility photos on the facility screen, and amenity names on each search result.
- **booking:** The review screen states the exact free-cancellation time, and the cancel dialog says whether you will be refunded.
- **auth:** Separate existing-account login from registration, add pre-OTP customer/owner selection, and complete registration through supported profile and owner-application APIs.
- **explore:** Search by a selected place and view nearby parking; the configured location remains available as the default.
- **profile:** Edit the profile name through the existing profile-update endpoint.
- **profile:** Edit and validate the email address through the existing profile-update endpoint.
- **booking:** Separate customer bookings into Upcoming and Past tabs using the API's status filters.

### Fixed
- **booking:** Refresh customer bookings when the app returns to the foreground, so server-side status changes no longer leave the active list stale.
- **owner:** Adding a photo no longer fails silently or locks the screen: photos come from the gallery, a file the picker cannot open, a non-JPG/PNG/WebP photo or one over 5 MB is explained, a large photo is never read into memory, and an unexpected answer from the server clears the busy state.
- **activity:** A notification meant for the owner opens in the owner area, decided by the server's `audience`.
- **tooling:** `tool/check.dart` no longer fails the app-name check on Windows line endings.

### Changed
- **booking:** Booking review and facility setup explain automatic approval and always create a booking instead of an owner request; the owner booking list opens on all statuses so online bookings awaiting payment are visible.
- **ios:** Minimum iOS version is now 15.0 (needed by Firebase). iOS 15 runs on every iPhone that runs iOS 13.
- **explore:** Keep the configured default as the active area while starting the editable location search field empty.
- **explore:** Distinguish empty parking results from filtered no-match results and show a specific no-place-match message.
- **api:** Report offline only for actual connection failures; unknown transport errors remain unexpected errors.

- **auth:** Show a retryable error instead of leaving startup loading when secure token storage fails.
- **auth:** Sign out locally without waiting for the server to revoke the session.
- **auth:** Refined the sign-in entry and phone screens, and show the verified mobile number while a new user completes their profile.
- **project:** Flutter project for Android and iOS (`com.swanlabstechnologies.parkeasy`).
- **docs:** Project overview, open decisions, architecture decision records, engineering conventions, process guides and onboarding.
- **ci:** GitHub Actions workflow: PR title, format, analysis and tests.
- **design:** Design system: principles, tokens with checked contrast, components, UX conventions, screen list and review notes.
- **owner:** Facility editor: create a facility, add spaces and rates, set opening hours, submit for review. Find a booking by its reference at the gate.
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

### Changed
- **owner:** Removed the Profile shortcut that duplicated the Bookings tab.
- **auth:** Route users into separate customer and owner navigation shells using backend-confirmed roles; hide Owner Area from customer Profile and keep pending applicants in the application flow.
- **profile:** Distinguish invalid email syntax from email addresses rejected by the API, such as an address already in use.
- **activity:** Open owner approval-request notifications in the owner booking screen while preserving customer booking links.
- **explore:** Keep the configured default as the active area while starting the editable location search field empty.
- **explore:** Distinguish empty parking results from filtered no-match results and show a specific no-place-match message.
- **api:** Report offline only for actual connection failures; unknown transport errors remain unexpected errors.
- **auth:** Show a retryable error instead of leaving startup loading when secure token storage fails.
- **auth:** Sign out locally without waiting for the server to revoke the session.