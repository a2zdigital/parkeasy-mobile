# Coding Standards

`dart format` and the analyzer settle formatting and most style; this page covers what they cannot.

## Dart

- `dart format` with the default line length. Do not hand-format.
- The analyzer runs with strict casts, inference and raw types, and CI fails on any issue, including infos. Do not add `// ignore`.
- `final` by default. No `dynamic`; no `!` on a value that can really be null; no `late` to avoid thinking about null.
- Models are immutable (`freezed`). Change by `copyWith`.
- A function either returns a value or throws a typed exception. Never return `null` to mean "failed".
- `async` functions are awaited or explicitly marked `unawaited`.
- No `print`. Use the app logger, and never log personal data.
- Comments say why, not what. Public classes in `core` have a doc comment.

## Widgets

- `const` constructors wherever possible.
- `StatelessWidget` or `ConsumerWidget` by default. `StatefulWidget` only for local UI state (a controller, an animation, focus).
- Extract a widget class, not a `_buildX()` method.
- `build` is pure: no requests, no navigation, no writes.
- Dispose every controller, focus node and subscription.
- After an `await`, check `context.mounted` before using `context`.
- Lists use builders (`ListView.builder`), never a column of hundreds of children.

## Theme and text

- Colours from `Theme.of(context).colorScheme` or the app's token extension. Never `Colors.blue` or `Color(0xFF…)` in a feature.
- Text styles from the theme's text styles. Never a literal `fontSize`.
- Spacing and radius from the spacing tokens. Never a literal number in `EdgeInsets` or `SizedBox` outside `core/theme`.
- Every user-facing string comes from localisation.

## Counter-examples

| Wrong | Right |
|---|---|
| `double total = json['total_amount']` | `Money.parse(json['total_amount'], json['currency'])` |
| `if (e.message.contains('unavailable'))` | `if (e.code == ApiErrorCode.slotUnavailable)` |
| `Text('Book now', style: TextStyle(fontSize: 16))` | `Text(l10n.bookNow, style: theme.textTheme.labelLarge)` |
| `onPressed: () async { await dio.post(...) }` | `onPressed: () => ref.read(provider.notifier).book()` |

## Files

- `snake_case.dart`. Tests end in `_test.dart` and mirror the path under `lib`.
- Generated files (`*.g.dart`, `*.freezed.dart`) are not committed and not edited.
