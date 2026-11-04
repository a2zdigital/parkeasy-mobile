# Components

The shared components in `lib/core/widgets`. A screen is assembled from these. If a screen needs something that is not here, the component is added here first, with its states, and then used.

> **Status:** Confirmed specification. **Implemented:** `PrimaryButton` (also its destructive form), `SecondaryButton`, `TextAction`, `AppTextField`, `OtpField`, `AppScaffold`, `EmptyState`, `ErrorState`, `AppBanner`, `AppLogo`, `CountdownBuilder`, `showConfirmDialog`, `StatusChip`, `AppFilterChip`, `AppCard`, `Skeleton`, `SkeletonCard`, `SectionHeader`, and in their features `FacilityCard`, `PriceBreakdown` and `BookingStatusChip` (the one place a booking status becomes a label, tone and icon). `CursorListView` draws any cursor-paged list with all its states; `TabShell` is the bottom-bar frame of both areas. The rest are built with the feature that first needs them.

Every interactive component has: default, pressed, focused, disabled. Those that start work also have loading.

## Buttons

| Component | Look | Use |
|---|---|---|
| `PrimaryButton` | Filled `primary`, `onPrimary` text, height 52, radius `control`, full width by default | The one main action of a screen |
| `SecondaryButton` | `surface` with a 1 px `borderControl` outline, `primary` text | An alternative action beside the primary |
| `TonalButton` | `primaryContainer` fill, `primaryPressed` text, height 48 | A compact action inside a card |
| `TextAction` | `primary` text, no container, 48 touch height | Low-emphasis action: "View all", "Change" |
| `DangerButton` | Filled `danger` | Only inside a confirmation for a destructive action |
| `IconAction` | 48 by 48, icon 24 | App bar and map controls |

- **Pressed:** `primaryPressed` fill, or a `surfaceSubtle` wash on unfilled buttons. **Focused:** a 2 px `primary` ring with a 2 px gap. **Disabled:** `surfaceSubtle` fill, `textDisabled` label.
- **Loading:** the label is replaced by a 20 px spinner, the width does not change, and the button ignores presses. A button that starts a request is always in this state until the answer arrives.
- One `PrimaryButton` per screen. Labels are a verb and a noun: "Book parking", "Pay ₹80.00", "Cancel booking". Never "OK" or "Submit".

## Inputs

| Component | Notes |
|---|---|
| `AppTextField` | Visible label above the field (`label` style), 52 high, `surface` fill, 1 px `borderControl`, radius `control`. Focus: 2 px `primary` border. Error: 2 px `danger` border, with the message and an icon beneath. Helper text sits in the same place as the error |
| `PhoneField` | Fixed `+91` prefix, numeric keyboard, formats as typed |
| `OtpField` | One box per digit, auto-advance, paste and SMS autofill, error state shakes once and clears |
| `SearchField` | Leading search icon, clear button when filled; on Explore it searches places through the API and shows selectable matches |
| `SegmentedControl` | Track `surfaceSubtle`, selected segment `surface` with level 1 elevation; two or three options only ("Hourly / Daily") |
| `DateTimeField` | Read-only field that opens the platform date and time pickers, showing the facility's timezone when it differs from the phone's |
| `FilterChip` | Pill, 36 high inside a 48 target; selected: `primaryContainer` fill, `primaryPressed` text and a check icon |

A placeholder is an example, never the label. A field keeps what the user typed when the request fails.

## Status

| Component | Notes |
|---|---|
| `StatusChip` | Pill; container colour, strong text, 16 px icon, `label` style. Takes a tone and a label. Always icon **and** text |
| `BookingStatusChip`, `PaymentStatusChip` | Thin wrappers that map the API's status to tone, icon and label. The mapping is in [ux-conventions.md](ux-conventions.md) and exists in exactly one place in code |
| `Banner` | Full-width block inside the page: container colour, icon, one or two sentences, optional `TextAction`. For conditions that persist: "Waiting for the owner's approval until 10:30 am" |
| `CountdownText` | Time left to a server deadline, tabular figures; turns `warning` under two minutes; announces changes to screen readers once a minute, not every second |

## Cards and rows

| Component | Contents |
|---|---|
| `FacilityCard` | Name (`h3`, two lines at most), distance and area (`bodySmall`), up to three amenity tags, price with its unit (`price` + `bodySmall`), availability chip. The whole card is one button. No image area in the first version; the layout reserves a leading slot so photos can be added without redesign |
| `BookingCard` | Facility name, date and time range, booking status chip, total, and the booking reference in tabular figures |
| `PriceBreakdown` | One row per quote line, a divider, the total in `price`. Values are exactly what the API returned |
| `InfoRow` | Icon, label, value: for facility details and the booking summary |
| `SectionHeader` | `h2` title with an optional `TextAction` on the right |
| `MetricTile` | Label (`label`) above a value (`h2`, tabular): owner earnings and counts |
| `AmenityTag` | Icon and word, neutral; never colour-coded |

A card is `surface`, radius `card`, 1 px `border`, padding 16, no shadow.

## Navigation and structure

| Component | Notes |
|---|---|
| `AppScaffold` | Applies the canvas colour, safe areas, the screen padding and the keyboard inset. Every screen uses it; no screen sets its own padding |
| `AppTopBar` | Title (`h2`), back button, up to two `IconAction`s. Level 0 until content scrolls under it |
| `BottomNav` | Four destinations, outlined icons, label always visible; selected: `primary` icon and label. No floating centre button |
| `ActionBar` | Pinned to the bottom above the safe area, level 2: a summary on the left (price, unit) and the `PrimaryButton` on the right. Used on facility details and the booking flow |
| `StepHeader` | "Step 2 of 3" with a thin progress bar. Text first; the circles in the concept board are not used |
| `AppBottomSheet` | Radius `sheet`, drag handle, title, content, actions; closes on back and on a downward drag |
| `ConfirmDialog` | Title as a question, one sentence of consequence, a `DangerButton` or `PrimaryButton` and a `TextAction` to go back |

## Feedback and states

| Component | Notes |
|---|---|
| `Skeleton` | `surfaceSubtle` blocks in the shape of the content that is coming. Used for first loads |
| `InlineSpinner` | 20 px; inside buttons and at the foot of a list that is loading more |
| `EmptyState` | Icon, a title that names the space, one sentence, one action |
| `ErrorState` | Icon, what happened in plain words, a "Try again" button, and the request ID in `label` style for support |
| `AppSnackbar` | One line confirming something that just happened; four seconds; at most one action. Never for errors the user must act on |
| `OfflineBar` | Thin bar under the app bar while the device has no connection |

## Map

| Component | Notes |
|---|---|
| `PriceMarker` | Pill with the hourly price; selected: `primary` fill. Unavailable: `surfaceSubtle` with `textSecondary` |
| `UserLocationMarker` | `primary` dot with a white ring |

The map view remains deferred; MD-02 selects Google Places for server-side place search, not a map SDK. The explore screen works as a list, with every provider result selectable.

## Brand

| Component | Notes |
|---|---|
| `AppLogo` | Renders the logo asset in the variant asked for (mark, or mark with wordmark; on light or on navy). The wordmark is part of the image: the name is never drawn as text beside the mark |

The files in `assets/brand/` are placeholders until the real artwork is saved under the same names. See [brand-assets.md](brand-assets.md).
