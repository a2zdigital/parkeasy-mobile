# Design Tokens

The only visual values a widget may use. In code they live in `lib/core/theme` and are read through the theme (`context.colors`, `context.space`, `Theme.of(context).textTheme`). A literal value outside `lib/core/theme` fails review. (`Colors.transparent` is the one literal allowed.)

> **Status:** **Implemented** in `lib/core/theme`. A test recalculates every contrast ratio below from the tokens.

## Colour

### Brand

| Token | Value | Use |
|---|---|---|
| `brandNavy` | `#101B35` | Launch and sign-in background, owner dashboard header, dark surfaces |
| `primary` | `#245BFF` | Filled buttons, links, selected states, the user's location |
| `primaryPressed` | `#1B47CC` | Pressed primary; text on `primaryContainer` |
| `primaryContainer` | `#E8EEFF` | Selected chip, tonal button, info banner background |
| `accentTeal` | `#16B8C8` | Map highlights, availability marker. **Never text on a light surface** |
| `onPrimary`, `onNavy` | `#FFFFFF` | Text and icons on `primary` and `brandNavy` |

### Neutrals

| Token | Value | Use |
|---|---|---|
| `canvas` | `#F5F7FB` | Screen background |
| `surface` | `#FFFFFF` | Cards, sheets, inputs, app bar |
| `surfaceSubtle` | `#EDF1F7` | Segmented control track, skeletons, neutral chip |
| `border` | `#DCE3EE` | Card outlines, dividers. Decorative only |
| `borderControl` | `#8693A6` | Outline of inputs, checkboxes and outlined buttons |
| `textPrimary` | `#172238` | Titles, body, prices |
| `textSecondary` | `#596579` | Supporting text, metadata, placeholders |
| `textDisabled` | `#98A2B3` | Disabled labels only |

### Status

Each tone has a solid colour (icons, text on white, filled banners), a container (chip background) and a strong colour (text on the container).

| Tone | Solid | Container | Strong | Means |
|---|---|---|---|---|
| `success` | `#16845B` | `#E3F4EC` | `#0F6B49` | Confirmed, paid, completed |
| `warning` | `#A96500` | `#FFF1DB` | `#8A5300` | Waiting: for approval, for payment |
| `danger` | `#C33745` | `#FCE8EA` | `#A82C3A` | Error, cancelled, rejected, unavailable, destructive action |
| `info` | `#245BFF` | `#E8EEFF` | `#1B47CC` | Neutral information |
| `available` | `#16B8C8` | `#E0F5F7` | `#0B6F79` | Space available |
| `neutral` | `#596579` | `#EDF1F7` | `#596579` | Finished without event: expired, no-show, past |

Green means *confirmed*, never merely *available*: availability has its own teal tone, so a user never mistakes "there is space" for "you have a booking".

### Checked contrast

Calculated with the WCAG formula. Text needs 4.5 to 1; large text (24 px, or 18.66 px bold) and control outlines need 3 to 1.

| Foreground on background | Ratio | Result |
|---|---|---|
| `onPrimary` on `primary` | 5.23 | Pass |
| `onPrimary` on `primaryPressed` | 7.45 | Pass |
| `onNavy` on `brandNavy` | 17.07 | Pass |
| `primary` on `surface` | 5.23 | Pass |
| `primary` on `canvas` | 4.88 | Pass |
| `primaryPressed` on `primaryContainer` | 6.42 | Pass |
| `textPrimary` on `surface` / `canvas` | 15.88 / 14.81 | Pass |
| `textSecondary` on `surface` / `canvas` / `surfaceSubtle` | 5.90 / 5.50 / 5.20 | Pass |
| `success` on `surface` | 4.68 | Pass |
| `successStrong` on `successContainer` | 5.72 | Pass |
| `warning` on `surface` | 4.62 | Pass |
| `warningStrong` on `warningContainer` | 5.68 | Pass |
| `danger` on `surface` | 5.31 | Pass |
| `dangerStrong` on `dangerContainer` | 5.79 | Pass |
| `availableStrong` on `availableContainer` | 5.21 | Pass |
| `onPrimary` on `success` / `danger` (filled) | 4.68 / 5.31 | Pass |
| `borderControl` on `surface` | 3.12 | Pass (control outline) |
| `border` on `surface` | 1.29 | Decorative only; never the sole boundary of a control |
| `accentTeal` on `surface` | 2.41 | **Fail for text.** Shapes and markers only, always with a label |
| `textDisabled` on `surface` | 2.58 | Allowed only for disabled controls, which are exempt |

Rejected values and the reasons are in [review-notes.md](review-notes.md). **A new colour pair is added to this table, with its ratio, before it is used.**

### Rules

- Colours are read by role (`context.colors.textSecondary`), never by hue.
- Do not use opacity to make a lighter text colour; use the token.
- Do not use Material's default `ColorScheme` roles that this table does not map. The mapping from these tokens to `ColorScheme` is written once in `lib/core/theme`.

## Typography

**Inter** 4.1, bundled in `assets/fonts` (weights 400, 500, 600, 700) so text never flashes or depends on the network. Licence: SIL Open Font Licence, kept beside the files.

| Token | Size / line height | Weight | Use |
|---|---|---|---|
| `display` | 32 / 40 | 700 | Launch screen message |
| `h1` | 28 / 36 | 700 | Screen title (large) |
| `h2` | 22 / 30 | 600 | Section heading, app bar title |
| `h3` | 18 / 26 | 600 | Facility name, card heading |
| `body` | 16 / 24 | 400 | Main content |
| `bodySmall` | 14 / 20 | 400 | Supporting detail |
| `label` | 12 / 16 | 500 | Chips, metadata, field labels |
| `button` | 16 / 20 | 600 | Buttons |
| `price` | 18 / 26 | 600, tabular figures | Prices and totals |

- Eight text styles and one numeric variant. There is no ninth.
- Prices, durations, counts and countdowns use tabular figures so digits do not shift.
- Sentence case everywhere. No all-capitals labels, no weight below 400, no text under 12 px.
- Sizes are logical pixels and scale with the user's text-size setting. Layouts are built to hold 200%.
- Letter spacing is Inter's default.

## Spacing

A 4-point grid.

| Token | Value | Typical use |
|---|---|---|
| `xs` | 4 | Icon to its label |
| `sm` | 8 | Between related items; chip gaps |
| `md` | 12 | Between rows inside a card |
| `lg` | 16 | Card padding; between cards |
| `xl` | 24 | Between sections |
| `xxl` | 32 | Above a screen's first block; before the main action |

| Layout constant | Value |
|---|---|
| Screen horizontal padding | 20 (16 when the screen is narrower than 360) |
| Card padding | 16 |
| Gap between list cards | 12 |
| Minimum touch target | 48 by 48 |
| Primary button height | 52 |
| Secondary control height | 48 |
| Input height | 52 |
| Bottom navigation height | 64, plus the safe area |

Every screen respects the safe areas and the keyboard inset; the main action stays visible above the keyboard.

## Radius

| Token | Value | Use |
|---|---|---|
| `small` | 8 | Chips, tags, small thumbnails |
| `control` | 12 | Buttons, inputs, segmented controls |
| `card` | 16 | Cards |
| `sheet` | 24 | Bottom sheets and dialogs (top corners of a sheet) |
| `pill` | 999 | Status chips, filter chips |

## Elevation

Flat by default. A card is separated from the canvas by its white surface and a 1 px `border`, not a shadow.

| Level | Shadow | Use |
|---|---|---|
| 0 | None | Cards, inputs, app bar on a white screen |
| 1 | `0 1 3` navy at 8% | App bar and bottom bar when content scrolls beneath them |
| 2 | `0 8 24` navy at 12% | Bottom sheets, dialogs, map controls, the pinned action bar |

No coloured shadows, no glow, no blur behind surfaces.

## Motion

| Token | Value | Use |
|---|---|---|
| `fast` | 100 ms | Pressed state, toggles |
| `base` | 200 ms | Chips, expanding rows, fades |
| `slow` | 300 ms | Sheets, page transitions |
| Curve | Ease out (enter), ease in (exit) | |

Motion explains a change of state and nothing else. No looping animation except a progress indicator. When the device asks for reduced motion, transitions become fades.

## Icons

Material Symbols, outlined, as shipped with Flutter (`Icons.*_outlined`): no icon package. 24 px by default, 20 px inside chips and dense rows, 1 colour. An icon that is the only content of a button has a semantic label. The logo mark is an image asset, not an icon.

## Names in code

| Token group | Access |
|---|---|
| Colours | `context.colors.<token>` (a `ThemeExtension`) |
| Text styles | `context.text.<token>` |
| Spacing and sizes | `AppSpace.<token>`, `AppSize.<token>`, and ready-made gaps (`Gap.lg()`) |
| Radius | `AppRadius.<token>` |
| Durations | `AppMotion.<token>` |
