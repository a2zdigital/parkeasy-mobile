import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A rounded, tinted square holding an icon: the leading mark of a card or
/// a row, so a list reads at a glance.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    this.size = AppSize.touchTarget,
    this.tone,
    super.key,
  });

  final IconData icon;
  final double size;

  /// The tile's colours; the brand's primary tint unless set.
  final ToneColors? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = tone?.container ?? colors.primaryContainer;
    final foreground = tone?.strong ?? colors.primary;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(icon, size: size * 0.5, color: foreground),
      ),
    );
  }
}

/// The top of a single-task screen (sign in, enter the code): an icon that
/// says what the step is about, a large title and one line of explanation.
class ScreenIntro extends StatelessWidget {
  const ScreenIntro({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIconTile(icon: icon, size: 56),
      const Gap.lg(),
      Text(title, style: context.text.h1),
      const Gap.sm(),
      Text(
        body,
        style: context.text.body.copyWith(color: context.colors.textSecondary),
      ),
    ],
  );
}

/// A small reassurance line with a lock, under a form that asks for
/// something personal.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.lock_outline,
            size: AppSize.iconSmall,
            color: colors.textSecondary,
          ),
        ),
        const Gap.sm(),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
