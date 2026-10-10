import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A block inside the page for a condition that persists or an action
/// that could not happen. Always an icon and words, never colour alone.
class AppBanner extends StatelessWidget {
  const AppBanner({
    required this.tone,
    required this.message,
    this.icon,
    super.key,
  });

  final StatusTone tone;
  final String message;
  final IconData? icon;

  static IconData _defaultIcon(StatusTone tone) => switch (tone) {
    StatusTone.success => Icons.check_circle_outline,
    StatusTone.warning => Icons.schedule_outlined,
    StatusTone.danger => Icons.error_outline,
    StatusTone.info ||
    StatusTone.available ||
    StatusTone.neutral => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors.tone(tone);

    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.container,
          borderRadius: AppRadius.controlAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon ?? _defaultIcon(tone),
                  size: AppSize.iconSmall,
                  color: colors.strong,
                ),
              ),
              const Gap.sm(),
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodySmall.copyWith(color: colors.strong),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
