import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Builds the Material theme from the design tokens. This is the only
/// place where tokens are mapped onto Material's own roles.
abstract final class AppTheme {
  static ThemeData light() {
    const colors = AppColors.light;
    final text = AppTextStyles.standard(color: colors.textPrimary);

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.primaryPressed,
      secondary: colors.brandNavy,
      onSecondary: colors.onNavy,
      error: colors.danger.solid,
      onError: colors.onPrimary,
      errorContainer: colors.danger.container,
      onErrorContainer: colors.danger.strong,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.borderControl,
      outlineVariant: colors.border,
      shadow: colors.shadow,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      fontFamily: AppTextStyles.fontFamily,
      extensions: [colors, text],
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: AppSize.borderWidth,
        space: AppSize.borderWidth,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: colors.shadow.withValues(alpha: 0.08),
        centerTitle: false,
        titleTextStyle: text.h2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.brandNavy,
        contentTextStyle: text.bodySmall.copyWith(color: colors.onNavy),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
      ),
    );
  }
}

/// Access to the tokens from a widget.
extension ThemeTokens on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppTextStyles get text => Theme.of(this).extension<AppTextStyles>()!;
}
