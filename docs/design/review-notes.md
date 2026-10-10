# Review Notes on the Reference Material

The design started from two concept boards and a written specification. They agree on direction and disagree on details. This page records each decision so nobody reopens it by accident.

## Which source wins

The written specification, then the boards. The specification is internally consistent and mostly passes contrast checks; the boards are illustrative.

## Changes and reasons

| # | Reference said | Decision | Reason |
|---|---|---|---|
| 1 | Boards: electric blue `#2F80FF` | `#245BFF` (specification) | White text on `#2F80FF` is 3.72 to 1, below the 4.5 needed for button labels. `#245BFF` gives 5.23 |
| 2 | Boards: navy `#0B1F44`, teal `#00C2A8` | `#101B35`, `#16B8C8` (specification) | One source of truth; the board teal is 2.26 to 1 on white |
| 3 | Boards: amber `#FFB020`, red `#FF4D4F` for status | `#A96500`, `#C33745` (specification) | Board amber is 1.83 to 1 and red 3.27 to 1 on white: unreadable as text |
| 4 | Specification: status text in the solid colour on its tinted chip | Added a "strong" shade per tone for text on the tint | Solid success on its tint is 4.11 and warning 4.15: just under 4.5. The strong shades give 5.7 |
| 5 | Specification: one border colour `#DCE3EE` for inputs | Added `borderControl` `#8693A6` for inputs and outlined buttons | `#DCE3EE` on white is 1.29 to 1; a control's boundary needs 3 to 1. The light border stays for cards and dividers |
| 6 | Specification: "green means confirmed, not merely available", yet its sample card shows a green "Available" chip | Availability gets its own teal tone | Resolves the contradiction and gives the teal accent a real job |
| 7 | Teal as a general secondary accent | Teal only for availability and map highlights, never as text on light surfaces | 2.41 to 1 on white |
| 8 | Boards: photo backgrounds, gradients and glow on the launch and marketing panels | Flat navy launch screen with the logo | The specification itself says to avoid gradients and effects; photos need assets and licences we do not have; a flat screen loads instantly |
| 9 | Boards: five tabs with a floating scan button | Four tabs, no floating button | Saved and scan have no API behind them. See [screens.md](screens.md) |
| 10 | Specification: tabs "Explore, Bookings, Saved, Activity, Profile" | Explore, Bookings, Activity, Profile | Same reason; Activity is the notifications list the API already provides |
| 11 | Boards: numbered circles for booking steps | "Step 2 of 3" text with a progress bar | Reads at large text sizes and to a screen reader; costs less width |
| 12 | Boards: date strip and a grid of time slots | Start and end pickers | The API prices any window; a slot grid would invent a constraint the product does not have |
| 13 | Boards: an 8-point grid; specification: a 4-point base | 4-point base, with the specification's six steps | The 12 px step is needed inside cards |
| 14 | Boards: radius 4 for small elements | Smallest radius is 8 | Fewer shapes; 4 looks sharp beside 12 and 16 |
| 15 | Boards: type scale with 20 px and 24 px headings | The specification's scale, plus one `price` style | Eight styles are enough; a numeric style with tabular figures was missing |
| 16 | Dark screens mixed with light ones | Light theme only for the first version, navy reserved for launch, sign-in and the owner header | The specification says the same; tokens are semantic so dark can follow |
| 17 | Disabled buttons as the way to guard a form | Buttons stay enabled and explain what is missing | A grey button gives no reason and is low-contrast by design |
| 18 | The name written as text beside the mark | The wordmark is part of the logo image; code never draws the name as styled text | The name may change; one asset swap and one line in `app_identity.json` must be enough |

## Still needed from outside the team

| Item | Why |
|---|---|
| Logo and app icon as vector files (mark, mark with wordmark, on light and on navy; adaptive icon layers for Android) | The boards are raster concept images and cannot be shipped. Concept 01, the pin mark, is the assumed direction |
| Confirmation of the colours above by whoever owns the brand | They follow the written specification, adjusted only where a check failed |
| The map decision (MD-02) | Decides whether Explore has a map view at launch |

## Not checked yet

The contrast table covers every pair defined in [tokens.md](tokens.md). Pairs on the map (markers over map tiles) cannot be checked until a map provider is chosen.
