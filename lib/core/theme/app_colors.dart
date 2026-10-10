import 'package:flutter/material.dart';

/// What a status colour is saying. Each tone has three colours; see
/// [ToneColors].
enum StatusTone { success, warning, danger, info, available, neutral }

/// The three colours of a [StatusTone].
@immutable
class ToneColors {
  const ToneColors({
    required this.solid,
    required this.container,
    required this.strong,
  });

  /// Icons, text on a white surface, filled banners.
  final Color solid;

  /// Chip and banner background.
  final Color container;

  /// Text and icons on [container].
  final Color strong;
}

/// Every colour the app may use, by role. Values and their checked
/// contrast ratios are in docs/design/tokens.md; `app_colors_test.dart`
/// recalculates the ratios, so a change here that breaks contrast fails.
///
/// Widgets read these through `context.colors`. A colour literal anywhere
/// outside `lib/core/theme` is a defect.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brandNavy,
    required this.primary,
    required this.primaryPressed,
    required this.primaryContainer,
    required this.accentTeal,
    required this.onPrimary,
    required this.onNavy,
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.borderControl,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.available,
    required this.neutral,
    required this.shadow,
  });

  /// The first version ships a light theme only.
  static const AppColors light = AppColors(
    brandNavy: Color(0xFF101B35),
    primary: Color(0xFF245BFF),
    primaryPressed: Color(0xFF1B47CC),
    primaryContainer: Color(0xFFE8EEFF),
    accentTeal: Color(0xFF16B8C8),
    onPrimary: Color(0xFFFFFFFF),
    onNavy: Color(0xFFFFFFFF),
    canvas: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEDF1F7),
    border: Color(0xFFDCE3EE),
    borderControl: Color(0xFF8693A6),
    textPrimary: Color(0xFF172238),
    textSecondary: Color(0xFF596579),
    textDisabled: Color(0xFF98A2B3),
    success: ToneColors(
      solid: Color(0xFF16845B),
      container: Color(0xFFE3F4EC),
      strong: Color(0xFF0F6B49),
    ),
    warning: ToneColors(
      solid: Color(0xFFA96500),
      container: Color(0xFFFFF1DB),
      strong: Color(0xFF8A5300),
    ),
    danger: ToneColors(
      solid: Color(0xFFC33745),
      container: Color(0xFFFCE8EA),
      strong: Color(0xFFA82C3A),
    ),
    info: ToneColors(
      solid: Color(0xFF245BFF),
      container: Color(0xFFE8EEFF),
      strong: Color(0xFF1B47CC),
    ),
    available: ToneColors(
      solid: Color(0xFF16B8C8),
      container: Color(0xFFE0F5F7),
      strong: Color(0xFF0B6F79),
    ),
    neutral: ToneColors(
      solid: Color(0xFF596579),
      container: Color(0xFFEDF1F7),
      strong: Color(0xFF596579),
    ),
    shadow: Color(0xFF101B35),
  );

  final Color brandNavy;
  final Color primary;
  final Color primaryPressed;
  final Color primaryContainer;

  /// Shapes and markers only. Never text on a light surface.
  final Color accentTeal;
  final Color onPrimary;
  final Color onNavy;

  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;

  /// Card outlines and dividers. Too faint to be a control's only boundary.
  final Color border;

  /// Outline of inputs and outlined buttons.
  final Color borderControl;

  final Color textPrimary;
  final Color textSecondary;

  /// Disabled labels only.
  final Color textDisabled;

  final ToneColors success;
  final ToneColors warning;
  final ToneColors danger;
  final ToneColors info;
  final ToneColors available;
  final ToneColors neutral;

  /// Base colour of elevation shadows, used at low opacity.
  final Color shadow;

  ToneColors tone(StatusTone tone) => switch (tone) {
    StatusTone.success => success,
    StatusTone.warning => warning,
    StatusTone.danger => danger,
    StatusTone.info => info,
    StatusTone.available => available,
    StatusTone.neutral => neutral,
  };

  // One theme exists, so there is nothing to override or blend. When a
  // dark theme is added these become real implementations.
  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors && t >= 0.5 ? other : this;
}
