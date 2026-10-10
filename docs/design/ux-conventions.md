# UX Conventions

How the app behaves, the same way on every screen.

## The four states of a screen

| State | Shown as | Rule |
|---|---|---|
| Loading (first) | `Skeleton` in the shape of the content | No full-screen spinner. If the data arrives within 150 ms, show nothing in between |
| Empty | `EmptyState` | Says what belongs here and offers the action that fills it |
| Error | `ErrorState` | Says what happened, offers "Try again", shows the request ID |
| Data | The content | Pull to refresh on every list and detail screen |

Lists also have **loading more** (a spinner at the foot) and **failed to load more** (a retry row at the foot, keeping what is already shown). Refreshing never replaces visible content with a skeleton.

## Errors

| Kind | Presentation |
|---|---|
| A field is wrong (`VALIDATION_FAILED`) | Message under that field, from the API's `details`; focus moves to the first one |
| The action cannot happen (`SLOT_UNAVAILABLE`, `QUOTE_EXPIRED`, `CANCELLATION_NOT_ALLOWED`…) | A `Banner` or dialog on the screen where it happened, in the app's own words, with the next step |
| The screen could not load | `ErrorState` |
| No connection | `OfflineBar`; actions that need the network explain that when pressed |
| Signed out, suspended, update required | Handled once for the whole app |

Every message says what happened and what to do next. "The last space was just taken. Choose another time or facility." Never "Error", "Something went wrong" alone, a code, or the server's raw text.

## Actions

- One primary action per screen, pinned in an `ActionBar` when the content scrolls.
- A press shows its pressed state immediately; the button shows loading until the answer; it cannot be pressed twice.
- Success is shown by the result itself (the new screen, the changed status). A snackbar confirms only when nothing else visibly changed.
- **Destructive or costly actions ask first**: cancel a booking, reject a request, sign out. The dialog states the consequence with real values: "Cancel this booking? ₹80.00 will be refunded." or "…No refund is due because it starts in less than an hour."
- Paying is never one accidental tap away: the amount is on the button.

## Forms

- Labels above fields. Validate a field when the user leaves it, and everything on submit. Do not show an error while the user is still typing the first time.
- The right keyboard for each field; "next" moves on, "done" submits.
- The submit button stays enabled; pressing it with missing fields shows what is missing. A permanently grey button explains nothing.
- Nothing typed is lost on an error, a rotation or a return from the background.

## Money

- Always from the API, shown as `₹1,250.00`: rupee sign, Indian digit grouping, two decimals. Whole amounts may drop the decimals only in compact places (map markers, list price): `₹40`.
- A price always carries its unit: `₹40 / hour`, `₹250 / day`.
- The total the user will pay is shown before the final action and on its button.
- Tabular figures. Never coloured green or red; money is `textPrimary`.

## Dates and times

- In the **facility's** timezone. When that differs from the phone's, say so: "10:00 am IST".
- Relative when near, absolute otherwise: "Today, 10:00 am – 12:00 pm", "Tue 16 Jul, 10:00 am – 12:00 pm". A booking across midnight shows both dates.
- 12-hour clock with am/pm, following the device's setting where it asks for 24-hour.
- Durations in words: "2 hours", "1 day 3 hours".
- Deadlines count down from the server's timestamp.

## Booking and payment status

The label, tone and icon for each status the API returns. This table is implemented once (`BookingStatusChip`, `PaymentStatusChip`).

| Booking `status` | Label | Tone | What the screen offers |
|---|---|---|---|
| `pending_approval` | Awaiting approval | warning | Countdown to the approval deadline; cancel |
| `awaiting_payment` | Payment pending | warning | Countdown to the payment deadline; "Pay ₹…"; cancel |
| `confirmed` | Confirmed | success | Reference for the gate; directions; cancel until the start |
| `confirmed` and checked in | Parked | success | Reference; end time |
| `completed` | Completed | neutral | Receipt details |
| `cancelled` | Cancelled | danger | Whether a refund is due |
| `rejected` | Not accepted | danger | Find another facility |
| `expired` | Expired | neutral | Book again |
| `no_show` | Missed | neutral | Book again |
| Unknown value | The raw value, capitalised | neutral | View only |

| Payment status | Label | Tone |
|---|---|---|
| `created`, `pending` | Confirming payment | warning |
| `succeeded` | Paid | success |
| `failed` | Payment failed | danger |
| `partially_refunded`, `refunded` | Refunded | neutral |
| Pay at facility, not collected | Pay at facility | info |
| Pay at facility, collected | Paid at facility | success |

Booking status and payment status are shown as separate chips when both matter. A booking that needs the owner's approval says so **before** the user books, and the confirmation screen says "Request sent", not "Booked".

## Navigation

- Customer tabs: **Explore**, **Bookings**, **Activity**, **Profile**. Owner area: **Dashboard**, **Bookings**, **Facilities**, **Earnings**, reached from Profile and remembered as the user's last role.
- A tab keeps its own history; pressing the current tab returns to its first screen.
- The booking flow is a linear stack with a `StepHeader`; back goes one step back and keeps the choices.
- The system back gesture always works. A screen with unsaved input asks before discarding.
- After a booking is created, back does not return to the form; it goes to the booking.

## Permissions

Location is asked for when the user first opens Explore, after one sentence explaining why. If refused, the app works by searching for a place, and never asks again on its own; a quiet "Use my location" action remains.

## Writing

- Sentence case. Plain words. Contractions are fine. No exclamation marks, no "please", no "successfully".
- Speak to the user as "you"; the app does not say "I" or "we".
- Buttons: verb and noun. Empty states: an invitation. Errors: what happened, then what to do.
- The app's name comes from `appDisplayName`. Sentences are written so the name can change length: never rely on it fitting a fixed width.

## Accessibility

Target WCAG 2.2 AA. Contrast pairs are fixed in [tokens.md](tokens.md) · targets are 48 by 48 · every control has a label, every status has text · the map always has a list alternative · layouts hold at 200% text · focus order follows reading order · reduced-motion is respected. Each new screen is checked once with TalkBack or VoiceOver before review.
