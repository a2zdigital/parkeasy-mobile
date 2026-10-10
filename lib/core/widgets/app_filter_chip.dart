import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// One choice in a row of filters. Selected is shown by fill, text colour
/// and a check mark together.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = isSelected ? colors.primaryPressed : colors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.pillAll,
        child: ConstrainedBox(
          // The visible pill is shorter; the touch target is not.
          constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: AppMotion.base,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryContainer : colors.surface,
                borderRadius: AppRadius.pillAll,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.borderControl,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(Icons.check, size: AppSpace.lg, color: foreground),
                    const Gap.xs(),
                  ],
                  Text(
                    label,
                    style: context.text.bodySmall.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
