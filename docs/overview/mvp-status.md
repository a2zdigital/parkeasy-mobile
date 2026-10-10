# MVP Status

What a tester can do on a phone today, and what is still needed before the app is a usable first version. Updated with every feature.

Last updated: 2026-10-10.

## Built and tested

| Area | What works |
|---|---|
| Sign-in | Phone number, SMS code with resend wait, name on first sign-in, staying signed in, sign out |
| Explore | Facilities around the pilot city centre, nearest first, with distance, starting price, approval and pay-at-facility flags; filter by vehicle type; paging; pull to refresh |
| Facility | Address, booking mode, payment modes, rates per vehicle type, opening hours, amenities |
| Choose time | Vehicle type, arrival and departure on the facility's clock, live price and availability, reasons a time cannot be booked |
| Review and book | Everything being committed to on one screen; pay at the facility or online; instant booking or a request to the owner; safe to retry without double-booking |
| Booking | Status, what to do next, reference for the gate, price, amount due at the facility; cancel after confirming, with the refund outcome shown |
| My bookings | Newest first, with status, time, total and reference; paging; pull to refresh |
| Activity | Notifications newest first, unread badge on the tab, mark one or all read, open the booking a notification is about |
| Owner area | Apply and see the application's status; bookings at your facilities filtered by status, opening on requests waiting; approve, reject, check in, record payment taken at the facility, check out; facilities with their review state (read-only); earnings summary and entries |
| Pay online | A "Pay ₹…" button on a booking waiting for payment; Razorpay checkout opened with the order our API creates; the booking is confirmed only when our API confirms the payment; clear outcomes for paid, failed, window closed and still confirming. On a test server the payment is simulated |
| Profile | Name, phone, email, sign out |
| Under everything | Loading, empty and error states; no-network handling; a refused token signs out; text scales to 200% |

Verified by automated tests only (logic and screens against a faked network). **Not yet run on a device by the team.**

## Still to build

| # | Feature | Notes |
|---|---|---|
| 1 | Owner facility editor | Create a facility, add spaces and rates, set opening hours, submit for review. Until then an owner's facilities are created through the API or the demo data; the app lists them and their review state |

**Both sides now work end to end against the API.** Customer: sign in → find → choose a time → book → pay online or at the facility → see the booking → cancel. Owner: apply → (approved by an admin) → answer requests → check in → record payment → check out → see earnings.

## Needed from outside the code

| Item | Blocks | Owner |
|---|---|---|
| A device run of the current build | Confirming the native settings (network permission, local HTTP in debug) | Technical lead |
| Staging API server | Anyone testing without running the API on their own machine | Technical lead |
| SMS provider on the API | Signing in with a real code; today only the fixed development code works, and only against a local API | Technical lead |
| Razorpay test keys on the API (`PARKEASY_PAYMENT_DRIVER=razorpay`) | Real checkout. **The Razorpay window itself has never been opened**: the SDK is integrated and its logic is tested with a stand-in, but only a device run with test keys proves the native side | Technical lead |
| Logo and app icon artwork | Replacing the placeholders; launcher icon | Design |
| Map decision (MD-02) | A map view in Explore | Technical lead |
| Tester distribution (MD-06) and signing (MD-09) | Giving a build to people outside the team | Technical lead |

## Known limits of what is built

| Limit | Reason |
|---|---|
| Explore searches around a fixed point (the city centre from configuration), not the phone's location | Device location needs a location package and permission texts, which must be tried on real devices |
| No search by place name | Needs a geocoding service behind our API |
| Search results do not show amenities | The API's search result carries amenity codes without names |
| Facility time zones other than India are shown in UTC | No time-zone database is bundled; the pilot is India only |
| The cancel confirmation cannot say in advance whether a refund is due; the booking shows it after cancelling | The API reports refund eligibility only in the cancellation result |
| The review screen describes the cancellation rule in general terms | The API does not expose the free-cancellation period to customers |
| Bookings are one list, newest first, not split into upcoming and past | The split needs a filter the API does not offer yet |
| A notification about a booking opens it as the customer's booking, except a new request, which opens the owner's view. An owner tapping "booking confirmed" or "cancelled" for their facility sees "couldn't find that booking" | Notifications do not say whether they are for the customer or the owner |
| The owner area has no dashboard; it opens on booking requests | Simpler, and requests are what an owner must act on |
| Owner earnings entries show times in India's zone | An entry carries no facility |
