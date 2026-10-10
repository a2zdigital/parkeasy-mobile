import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A small label for a state. Always words, and an icon when one helps;
/// colour supports the meaning but never carries it alone.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.tone,
    required this.label,
    this.icon,
    super.key,
  });

  final StatusTone tone;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors.tone(tone);
    final icon = this.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(icon, size: AppSpace.lg, color: colors.strong),
              ),
              const Gap.xs(),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.label.copyWith(color: colors.strong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
