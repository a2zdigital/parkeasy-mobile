# Design

The design system for the app: what it looks like, how it behaves, and how that is written in code.

> **Status:** Confirmed as the design to build. Nothing here is Implemented yet; `lib/core/theme` and `lib/core/widgets` are built first, before any screen.

| File | Contents |
|---|---|
| [principles.md](principles.md) | The four principles, and what "built by an engineer, not generated" means in practice |
| [tokens.md](tokens.md) | Colour, typography, spacing, radius, elevation, motion: the only values a widget may use |
| [components.md](components.md) | Every shared component, its variants and its states |
| [ux-conventions.md](ux-conventions.md) | Loading, empty, error, forms, confirmation, money, time, status |
| [screens.md](screens.md) | Every screen in the first version, the API call behind it, and what is deferred |
| [review-notes.md](review-notes.md) | Where the reference material was changed, and why |
| [brand-assets.md](brand-assets.md) | The logo and icon files: names, sizes, how to replace the placeholders |
| [reference/](reference/) | The two concept boards this design started from |

## How to read the reference boards

The images in `reference/` set the **direction**: navy and electric blue, the pin mark, Inter, clean cards, a map-first explore screen. They are concept art, not a specification:

- They show features the product does not have (wallet, cashback, reviews, QR entry, saved spots). See [screens.md](screens.md).
- Some of their colours fail contrast checks. The values in [tokens.md](tokens.md) are the checked ones.

**When a board and these documents disagree, the documents are right.**

## The app's name

The name shown to users has one source, `app_identity.json`, and may change. Never type it in code, in a string file, in a widget or in a test; use `appDisplayName`. `dart run tool/check.dart` fails if it finds the name anywhere else. The logo and wordmark are image assets, replaced together when the name changes. These documents say "the app" for the same reason.
