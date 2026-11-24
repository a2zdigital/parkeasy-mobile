import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Two to four mutually exclusive views of the same list (Upcoming / Past,
/// Requests / Confirmed …). Equal widths; a white thumb slides to the
/// selected segment.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  }) : assert(segments.length >= 2 && segments.length <= 4);

  final List<(T value, String label)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final index = segments
        .indexWhere((segment) => segment.$1 == selected)
        .clamp(0, segments.length - 1);
    final duration = reduceMotion(context) ? Duration.zero : AppMotion.base;

    return Container(
      height: AppSize.controlHeight,
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: AppRadius.controlAll,
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duration,
            curve: AppMotion.enter,
            alignment: Alignment(
              segments.length == 1 ? 0 : -1 + 2 * index / (segments.length - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / segments.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.smallAll,
                  boxShadow: AppShadows.card(colors),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (value, label) in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == selected,
                    child: InkWell(
                      borderRadius: AppRadius.smallAll,
                      onTap: () {
                        if (value != selected) onChanged(value);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: text.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: value == selected
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
