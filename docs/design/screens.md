# Screens

Every screen in the first version, and the API call behind it. A screen is in scope only if the API supports it today.

> **Status:** Confirmed scope. **Implemented:** C1 to C4 (welcome with login or registration, role selection, phone, code, customer details, and owner application), C5 (Explore, list only, starts around the configured city centre with an initially empty place-search field), C6 (facility), C7 (choose time, with price and availability), C8 (review and book), C10 and C12 (the booking screen is also the result screen; cancel), C11 (Upcoming and Past booking lists), C14 (profile: view, edit name and email, and sign out), and the four-tab shell. C13 (Activity). Owner: O1 (apply and status), O3 and O4 (bookings and every booking action), O5 (facilities), O6 (facility editor: details, spaces and rates, opening hours, submit), O7 (earnings). O2 (dashboard) is replaced by the bookings list opening on requests. C9 (paying online) is built; the Razorpay window has not been tried on a device. Progress: [mvp-status.md](../overview/mvp-status.md).

## Customer

| # | Screen | Main content | API |
|---|---|---|---|
| C1 | Welcome | Navy, logo, sign-in or account-creation hint, log in or create an account | — |
| C2 | Account choice and phone | Existing-account login, or role selection followed by phone entry for registration; SMS verification and account-creation explanation | `POST /auth/otp/request` |
| C3 | Verification code | `OtpField`, resend countdown | `POST /auth/otp/verify` |
| C4 | Customer details (new users) | Verified mobile number, required name, optional email; owner applicants continue to the owner application | `PATCH /me`, `POST /owner/application` |
| C5 | Explore | Initially empty place-search field, filter chips (vehicle type, amenities), results as `FacilityCard`s nearest first; friendly empty and no-match states; map view remains deferred | `GET /places/search`, `GET /parking-lots` |
| C6 | Facility details | Name, address, distance, hours, amenities, rates per vehicle type, booking mode and payment modes; `ActionBar` "Choose time" | `GET /parking-lots/{id}` |
| C7 | Choose time | Vehicle type, start and end (`DateTimeField`), live availability and price | `GET …/availability`, `POST /bookings/quote` |
| C8 | Review and book | `PriceBreakdown`, payment mode, instant or approval notice, cancellation rule; "Book parking" / "Send request" | `POST /bookings` |
| C9 | Payment | Opens checkout, then "Confirming payment" until the API answers | `POST …/payment-orders`, `GET …/payment` |
| C10 | Booking result | Confirmed, request sent, or payment failed, each with its next step | `GET /bookings/{id}` |
| C11 | Bookings | Upcoming active statuses and past terminal statuses, `BookingCard`s | `GET /bookings?filter[status]=…` |
| C12 | Booking details | Status, reference, times, facility, price, payment; cancel | `GET /bookings/{id}`, `POST …/cancel` |
| C13 | Activity | Notifications, unread first | `GET /notifications`, read endpoints |
| C14 | Profile | Name, phone, email, edit name and email (phone remains read-only), sign out | `GET /me`, `PATCH /me`, `POST /auth/logout` |

The journey designed first: **Explore → Facility → Choose time → Review → Pay or pay at facility → Result → Booking details.**

The mobile API does not accept a requested role during OTP registration: new accounts receive the `customer` role. Owner onboarding uses `POST /owner/application` with the business name and the already verified phone number; the backend grants the `owner` role only after approval. The selected owner option is onboarding intent only and never grants access.

The customer and owner experiences use separate navigation shells. Customers keep the four customer tabs and do not see an Owner Area link in Profile. Users with the backend-confirmed owner role open the owner bookings shell; applicants without that role can see only their owner application/status flow. Owner routes remain protected by the backend as well as by client-side routing.

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
| Map with price pins | Map UI and a client Maps SDK remain deferred; MD-02 selected only the server-side place-search provider | Search and choose a place, then see the list |

Each of these can be added when the API and the product decision exist. None may be mocked in the meantime.
