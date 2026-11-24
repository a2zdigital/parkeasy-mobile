import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Rows of settings or links inside one card, separated by hairlines: the
/// standard list for menus such as Profile.
class AppListGroup extends StatelessWidget {
  const AppListGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
        boxShadow: AppShadows.card(colors),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardAll,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                const Divider(
                  indent: AppSpace.lg + AppSize.touchTarget,
                  height: AppSize.borderWidth,
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// One row: an icon in a tinted tile, a title, an optional subtitle, and a
/// chevron when it leads somewhere. 56 px high at least, the whole row
/// pressable.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.tone,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Replaces the chevron, such as a value or a switch.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Sign out and similar: danger colours, no chevron.
  final bool isDestructive;

  /// The icon tile's colours; info unless set (danger when destructive).
  final ToneColors? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tone = isDestructive ? colors.danger : (this.tone ?? colors.info);
    final subtitle = this.subtitle;
    final trailing =
        this.trailing ??
        (onTap != null && !isDestructive
            ? Icon(
                Icons.chevron_right,
                size: AppSize.icon,
                color: colors.textSecondary,
              )
            : null);

    return PressScale(
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: AppSize.iconTile,
                    height: AppSize.iconTile,
                    decoration: BoxDecoration(
                      color: tone.container,
                      borderRadius: AppRadius.smallAll,
                    ),
                    child: Icon(
                      icon,
                      size: AppSize.iconSmall,
                      color: tone.strong,
                    ),
                  ),
                ),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDestructive
                              ? colors.danger.strong
                              : colors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: text.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const Gap.sm(), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A person's initials in a tinted circle. There are no profile photos in
/// the API, so this stands in without pretending to be one.
class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.name, this.size = 56, super.key});

  final String? name;
  final double size;

  static String initials(String? name) {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final letters = initials(name);

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
        ),
        child: letters.isEmpty
            ? Icon(
                Icons.person_outline,
                color: colors.primary,
                size: size * 0.5,
              )
            : Text(
                letters,
                style: context.text.h3.copyWith(
                  color: colors.primaryPressed,
                  fontSize: size * 0.36,
                ),
              ),
      ),
    );
  }
}
