import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text input with a visible label above it, and helper or error text
/// below. The error replaces the helper in the same place, so the layout
/// does not jump.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.focusNode,
    this.errorText,
    this.helperText,
    this.hintText,
    this.prefixText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final String? helperText;

  /// An example of valid input. Never a substitute for [label].
  final String? hintText;
  final String? prefixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final hasError = errorText != null;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: AppRadius.controlAll,
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: text.label.copyWith(color: colors.textSecondary),
          ),
        ),
        const Gap.xs(),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: text.body,
          cursorColor: colors.primary,
          decoration: InputDecoration(
            // Read by screen readers; the visible label is the Text above.
            semanticCounterText: '',
            labelText: null,
            hintText: hintText,
            hintStyle: text.body.copyWith(color: colors.textSecondary),
            prefixText: prefixText,
            prefixStyle: text.body,
            filled: true,
            fillColor: enabled ? colors.surface : colors.surfaceSubtle,
            constraints: const BoxConstraints(minHeight: AppSize.inputHeight),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            enabledBorder: border(
              hasError ? colors.danger.solid : colors.borderControl,
              hasError ? AppSize.focusBorderWidth : AppSize.borderWidth,
            ),
            focusedBorder: border(
              hasError ? colors.danger.solid : colors.primary,
              AppSize.focusBorderWidth,
            ),
            disabledBorder: border(colors.border, AppSize.borderWidth),
          ),
        ).withSemanticsLabel(label),
        const Gap.xs(),
        _SupportingText(error: errorText, helper: helperText),
      ],
    );
  }
}

class _SupportingText extends StatelessWidget {
  const _SupportingText({required this.error, required this.helper});

  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final error = this.error;

    if (error != null) {
      return Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: AppSize.iconSmall,
              color: colors.danger.solid,
            ),
            const Gap.xs(),
            Expanded(
              child: Text(
                error,
                style: text.bodySmall.copyWith(color: colors.danger.solid),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      helper ?? '',
      style: text.bodySmall.copyWith(color: colors.textSecondary),
    );
  }
}

extension on Widget {
  Widget withSemanticsLabel(String label) =>
      Semantics(label: label, textField: true, child: this);
}
