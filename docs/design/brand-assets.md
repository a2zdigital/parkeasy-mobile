# Brand Assets

The logo and icon files. **The files in the repository today are placeholders** (a blue disc, and a bar where the wordmark goes). To install the real artwork, save each image under exactly the name below, replacing the placeholder. No code changes.

| File | What it is | Size and format | Background |
|---|---|---|---|
| `assets/brand/logo_mark.png` | The pin mark alone | Square, at least 512 × 512, PNG | Transparent |
| `assets/brand/logo_full_on_light.png` | Mark with the wordmark, dark lettering | About 4 : 1 wide, at least 1200 px wide, PNG | Transparent |
| `assets/brand/logo_full_on_dark.png` | Mark with the wordmark, white lettering | Same proportions as the light version | Transparent |
| `assets/brand/app_icon.png` | The launcher icon artwork | Square, 1024 × 1024, PNG, no rounded corners | Solid (navy `#101B35`), **no transparency**: the App Store rejects it |

Rules for the artwork:

- Trim empty space: the image's edges should touch the artwork, apart from the app icon, which keeps its own margin (the mark inside the central 66%, so Android's round and squircle masks do not cut it).
- The two full logos must have identical proportions, so they are interchangeable in a layout.
- PNG is used so no extra package is needed. If vector files (SVG) are supplied later, adding SVG support is a dependency decision.

## In code

Paths are constants in `lib/core/config/brand_assets.dart` (`BrandAssets.mark` and so on); a test fails if a file is missing or renamed. Widgets use the `AppLogo` component (Planned), never `Image.asset` with a path.

The wordmark is part of the image. If the app is renamed, replace the two full logos and the icon, and change `app_identity.json`.

## Launcher icons

`app_icon.png` is the source only. The platform icon sets in `android/` and `ios/` are still Flutter's defaults. Generating them from this file is **Planned**, once the real artwork arrives.
