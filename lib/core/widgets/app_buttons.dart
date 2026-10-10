import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The one main action of a screen. Filled, full width.
///
/// While [isLoading] the label is replaced by a spinner, the size does
/// not change, and presses are ignored: an action cannot be sent twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    super.key,
  });

  final String label;

  /// Null disables the button. Prefer keeping it enabled and explaining
  /// what is missing when pressed.
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Filled with the danger colour. Only inside a confirmation.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = isDestructive ? colors.danger.solid : colors.primary;
    final pressed = isDestructive
        ? colors.danger.strong
        : colors.primaryPressed;

    return _Busy(
      isLoading: isLoading,
      label: label,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(AppSize.primaryButtonHeight),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
          ),
          textStyle: WidgetStatePropertyAll(context.text.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textDisabled
                : colors.onPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.surfaceSubtle;
            }
            return states.contains(WidgetState.pressed) ? pressed : fill;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
        ),
        child: _Label(
          label: label,
          isLoading: isLoading,
          spinnerColor: colors.onPrimary,
        ),
      ),
    );
  }
}

/// An alternative action beside the primary one. Outlined.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Busy(
      isLoading: isLoading,
      label: label,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(AppSize.controlHeight),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: colors.borderControl)),
          textStyle: WidgetStatePropertyAll(context.text.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textDisabled
                : colors.primary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? colors.surfaceSubtle
                : colors.surface,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: _Label(
          label: label,
          isLoading: isLoading,
          spinnerColor: colors.primary,
        ),
      ),
    );
  }
}

/// A low-emphasis action: "Change number", "View all".
class TextAction extends StatelessWidget {
  const TextAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSize.touchTarget, AppSize.touchTarget),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        ),
        textStyle: WidgetStatePropertyAll(context.text.button),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textDisabled;
          }
          return isDestructive ? colors.danger.solid : colors.primary;
        }),
        overlayColor: WidgetStatePropertyAll(colors.surfaceSubtle),
      ),
      child: Text(label),
    );
  }
}

/// Blocks presses and tells assistive technology the button is busy.
class _Busy extends StatelessWidget {
  const _Busy({
    required this.isLoading,
    required this.label,
    required this.child,
  });

  final bool isLoading;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: isLoading,
    liveRegion: isLoading,
    child: IgnorePointer(ignoring: isLoading, child: child),
  );
}

class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.isLoading,
    required this.spinnerColor,
  });

  final String label;
  final bool isLoading;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    // The label stays in the tree, invisible, so the button keeps its width.
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: isLoading ? 0 : 1,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (isLoading)
          SizedBox.square(
            dimension: AppSize.spinner,
            child: CircularProgressIndicator(
              strokeWidth: AppSize.focusBorderWidth,
              color: spinnerColor,
            ),
          ),
      ],
    );
  }
}
