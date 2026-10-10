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
| Profile | Name, phone, email, sign out |
| Under everything | Loading, empty and error states; no-network handling; a refused token signs out; text scales to 200% |

Verified by automated tests only (logic and screens against a faked network). **Not yet run on a device by the team.**

## Needed for a first test version (MVP)

In build order. The API already supports all of these.

| # | Feature | Notes |
|---|---|---|
| 1 | Review and book | Price summary, payment mode, instant or request, cancellation rule; create the booking with an idempotency key |
| 2 | Booking result and details | Confirmed, request sent, awaiting payment; reference; cancel with the refund consequence |
| 3 | My bookings | Upcoming and past |
| 4 | Pay online | Simulated payment against the local API first; Razorpay checkout when test keys exist |
| 5 | Activity | Notifications list, unread count, mark read |
| 6 | Owner area | Apply, bookings (approve, reject, check in, record payment, check out), earnings; facility editor last |

Items 1 to 3 with pay-at-facility make the shortest end-to-end journey a tester can complete.

## Needed from outside the code

| Item | Blocks | Owner |
|---|---|---|
| A device run of the current build | Confirming the native settings (network permission, local HTTP in debug) | Technical lead |
| Staging API server | Anyone testing without running the API on their own machine | Technical lead |
| SMS provider on the API | Signing in with a real code; today only the fixed development code works, and only against a local API | Technical lead |
| Razorpay test keys on the API | Real checkout | Technical lead |
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
| The choose-time screen ends with a note instead of a "Book" action | Booking is the next feature |
| Bookings and Activity tabs show "Not built yet" | Next features |
