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
| Owner area | Apply and see the application's status; bookings at your facilities filtered by status, opening on requests waiting, or found by reference; approve, reject, check in, record payment taken at the facility, check out; earnings summary and entries |
| Facility editor | Create a facility (details, location, booking mode, payments, amenities); add spaces and rates per vehicle type; set opening hours; submit for review; see why it was not approved and submit again. A facility in review is locked |
| Pay online | A "Pay ₹…" button on a booking waiting for payment; Razorpay checkout opened with the order our API creates; the booking is confirmed only when our API confirms the payment; clear outcomes for paid, failed, window closed and still confirming. On a test server the payment is simulated |
| Profile | Name, phone, email, sign out |
| Under everything | Loading, empty and error states; no-network handling; a refused token signs out; text scales to 200% |

Verified by automated tests only (logic and screens against a faked network). **Not yet run on a device by the team.**

## Still to build

Nothing in the agreed first-version scope. Every screen in [screens.md](../design/screens.md) that the API supports is built.

**Both sides work end to end against the API.** Customer: sign in → find → choose a time → book → pay online or at the facility → see the booking → cancel. Owner: apply → (approved by an admin) → create a facility → (approved by an admin) → answer requests → check in → record payment → check out → see earnings.

## Check-in at the gate: what exists and what does not

| | Today |
|---|---|
| How a vehicle is checked in | The owner, signed in, finds the booking in their list or by typing the reference the customer shows, and presses **Check in**; later **Check out** |
| Check-in by scanning a QR code | **Not built**, in the app or the API |
| Check-in by a one-time code (OTP) the customer reads out | **Not built**, in the app or the API |
| A separate login for a gate attendant or manager | **Not built**. Only the owner's own account can check vehicles in |

What QR and OTP check-in need, in order:

1. **API:** a gate-staff role tied to a facility; a per-booking check-in code and QR token that the API issues and verifies; endpoints to check in and out by code or token. The token must be verified by the server, not trusted because the app scanned it.
2. **App, customer:** the QR and the code on the booking screen.
3. **App, gate:** a scan screen (a camera package and camera permission, which must be tried on real devices) and a code-entry screen.
4. **Decisions:** whether check-out also needs a code; what happens without a network at the gate; whether the owner or an admin creates gate staff.

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
| A facility's location is typed as latitude and longitude | Picking it on a map needs the map decision (MD-02) |
| A rate cannot be removed once set, only changed | The API has no call to remove a rate |
| No facility photos | The API has no image upload |
| Owner earnings entries show times in India's zone | An entry carries no facility |

## Later versions

Named by the technical lead for a later, advanced version. **Not designed, not scheduled, and nothing in the current build prepares for them.** Each needs its own product and API design first.

RFID access · FASTag payment · vehicle insurance and PUC (pollution certificate) records · EV charging stations at facilities.
