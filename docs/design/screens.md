# Screens

Every screen in the first version, and the API call behind it. A screen is in scope only if the API supports it today.

> **Status:** Confirmed scope. **Implemented:** C1 to C4 (launch, phone, code, name), C5 (Explore, list only, around the configured city centre), C6 (facility), C7 (choose time, with price and availability), C8 (review and book), C10 and C12 (the booking screen is also the result screen; cancel), C11 (bookings, one list newest first), C14 (profile: view and sign out), and the four-tab shell. C13 (Activity). Owner: O1 (apply and status), O3 and O4 (bookings and every booking action), O5 (facilities), O6 (facility editor: details, spaces and rates, opening hours, submit), O7 (earnings). O2 (dashboard) is replaced by the bookings list opening on requests. C9 (paying online) is built; the Razorpay window has not been tried on a device. Progress: [mvp-status.md](../overview/mvp-status.md).

## Customer

| # | Screen | Main content | API |
|---|---|---|---|
| C1 | Launch | Navy, logo, sign-in or account-creation hint, "Get started" | — |
| C2 | Phone number | Mobile number, SMS verification and account-creation explanation; "Send code" | `POST /auth/otp/request` |
| C3 | Verification code | `OtpField`, resend countdown | `POST /auth/otp/verify` |
| C4 | Your name (new users) | Verified mobile number, name, optional email | `PATCH /me` |
| C5 | Explore | Search field, filter chips (vehicle type, amenities), results as `FacilityCard`s nearest first; map view when MD-02 is decided | `GET /parking-lots` |
| C6 | Facility details | Name, address, distance, hours, amenities, rates per vehicle type, booking mode and payment modes; `ActionBar` "Choose time" | `GET /parking-lots/{id}` |
| C7 | Choose time | Vehicle type, start and end (`DateTimeField`), live availability and price | `GET …/availability`, `POST /bookings/quote` |
| C8 | Review and book | `PriceBreakdown`, payment mode, instant or approval notice, cancellation rule; "Book parking" / "Send request" | `POST /bookings` |
| C9 | Payment | Opens checkout, then "Confirming payment" until the API answers | `POST …/payment-orders`, `GET …/payment` |
| C10 | Booking result | Confirmed, request sent, or payment failed, each with its next step | `GET /bookings/{id}` |
| C11 | Bookings | Upcoming and past, `BookingCard`s | `GET /bookings` |
| C12 | Booking details | Status, reference, times, facility, price, payment; cancel | `GET /bookings/{id}`, `POST …/cancel` |
| C13 | Activity | Notifications, unread first | `GET /notifications`, read endpoints |
| C14 | Profile | Name, phone, email, switch to owner area, sign out | `GET /me`, `PATCH /me`, `POST /auth/logout` |

The journey designed first: **Explore → Facility → Choose time → Review → Pay or pay at facility → Result → Booking details.**

## Owner

| # | Screen | Main content | API |
|---|---|---|---|
| O1 | Become an owner | Application form; then its status | `POST`, `GET /owner/application` |
| O2 | Dashboard | Requests waiting, today's bookings, payable balance and commission owed (`MetricTile`s) | `GET /owner/bookings`, `GET /owner/earnings` |
| O3 | Bookings | Filter by status and facility; find by reference | `GET /owner/bookings` |
| O4 | Booking (owner) | Approve or reject; check in; record payment at facility; check out | The owner booking endpoints |
| O5 | Facilities | List with review status | `GET /owner/parking-lots` |
| O6 | Facility editor | Details, location, spaces per vehicle type, rates, opening hours, submit for review | The owner facility endpoints |
| O7 | Earnings | Summary and entries | `GET /owner/earnings`, `/entries` |

The owner sees a booking's reference, never the customer's name or phone.

## Shown in the concept boards, not in the first version

| In the boards | Why not now | What the app does instead |
|---|---|---|
| Wallet, "Add money", cashback | No wallet in the API; a stored-value wallet is also a regulated product in India | Pay online per booking, or at the facility |
| Ratings and reviews | No reviews in the API | Nothing shown. No placeholder stars |
| Facility photos | No image upload or URLs in the API | Cards and details designed without images, with a slot reserved |
| Saved spots, favourites tab | No API | Tab removed; four tabs |
| "Scan and park", QR entry, the centre scan button | No QR or gate integration; check-in is done by the owner | The booking reference, large, for the attendant |
| Saved vehicles, payment methods | No API; cards are held by Razorpay, not by us | Vehicle type is chosen per booking |
| Apple, Google sign-in | The API signs in by phone and code only | Phone and code |
| Fixed time-slot grid, "2 hours save 8%" | The API prices any start and end, by started hour or day, and has no multi-hour discount | Start and end pickers; the quote shows the real price |
| Owner charts: occupancy, revenue by hour | The API offers an earnings summary and entries, not time series | `MetricTile`s and the entries list |
| Support chat, invite and earn | Not in scope | A support contact in Profile |
| Map with price pins | Needs a map provider and key (MD-02) | List first; map added as a second view |

Each of these can be added when the API and the product decision exist. None may be mocked in the meantime.
