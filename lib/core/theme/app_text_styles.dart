import 'package:flutter/material.dart';

/// The app's nine text styles. There is no tenth: if a design needs
/// another size, the design is reconsidered first. Values: docs/design/tokens.md.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.button,
    required this.price,
  });

  /// Builds the styles in one text colour. Widgets override the colour
  /// with `copyWith(color: …)` using a colour token when they need another.
  factory AppTextStyles.standard({required Color color}) {
    TextStyle style(double size, double lineHeight, FontWeight weight) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          color: color,
          leadingDistribution: TextLeadingDistribution.even,
        );

    return AppTextStyles(
      display: style(32, 40, FontWeight.w700),
      h1: style(28, 36, FontWeight.w700),
      h2: style(22, 30, FontWeight.w600),
      h3: style(18, 26, FontWeight.w600),
      body: style(16, 24, FontWeight.w400),
      bodySmall: style(14, 20, FontWeight.w400),
      label: style(12, 16, FontWeight.w500),
      button: style(16, 20, FontWeight.w600),
      price: style(
        18,
        26,
        FontWeight.w600,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  /// Bundled with the app in assets/fonts (weights 400, 500, 600, 700).
  static const String fontFamily = 'Inter';

  final TextStyle display;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle button;

  /// Prices, totals, references and countdowns: digits do not shift.
  final TextStyle price;

  @override
  AppTextStyles copyWith() => this;

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) =>
      other is AppTextStyles && t >= 0.5 ? other : this;
}
