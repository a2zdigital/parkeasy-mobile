# Localisation and Accessibility

## Localisation

The first version is English. More languages are an open decision (MD-03), so all text goes through localisation from the first screen.

- Strings live in `lib/l10n/app_en.arb`. Widgets use the generated `AppLocalizations`.
- Keys are camelCase and say what the text is for: `bookingCancelConfirmTitle`, not `text12`.
- The app's name is a placeholder in every string that mentions it (`{appName}`), filled from `appDisplayName`. It is never written in an ARB file.
- Never build a sentence by joining strings. Use placeholders and plurals in the ARB file.
- Dates, times and numbers are formatted with `intl` for the user's locale; money with the money formatter.
- The API's error `message` is English and is a fallback only. Screens show the app's own text for the codes they handle.
- Leave room: text in other languages can be 40% longer. No fixed-width buttons.

## Accessibility

- Every tappable control is at least 48 by 48 logical pixels.
- Every icon-only button has a tooltip or semantic label; decorative images are excluded from semantics.
- Text and its background meet a contrast ratio of 4.5 to 1 (3 to 1 for large text). The design system's colour pairs are chosen to pass.
- Colour is never the only signal: a status has a label or an icon as well.
- Screens stay usable at 200% text size: no clipped text, no overlapping controls.
- Form fields have visible labels, not only placeholders, and errors are announced next to the field.
- Check new screens with TalkBack or VoiceOver once before review.
