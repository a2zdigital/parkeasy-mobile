/// The brand images, by role. Replace the files; never change these names.
/// What each file must be is in docs/design/brand-assets.md.
abstract final class BrandAssets {
  /// The mark alone, on a transparent background.
  static const String mark = 'assets/brand/logo_mark.png';

  /// Mark and wordmark, for light surfaces.
  static const String fullOnLight = 'assets/brand/logo_full_on_light.png';

  /// Mark and wordmark, for the navy surface.
  static const String fullOnDark = 'assets/brand/logo_full_on_dark.png';

  /// Source image for the launcher icon. Not shown inside the app.
  static const String appIcon = 'assets/brand/app_icon.png';

  static const List<String> all = [mark, fullOnLight, fullOnDark, appIcon];
}
