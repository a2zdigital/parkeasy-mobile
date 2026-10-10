import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The standard card: white surface, a hairline border, no shadow. With
/// [onTap] the whole card is one button.
class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(colors.surfaceSubtle),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: child,
        ),
      ),
    );
  }
}

/// A grey block in the shape of content that is loading.
class Skeleton extends StatelessWidget {
  const Skeleton({required this.height, this.width, super.key});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: AppRadius.smallAll,
      ),
    ),
  );
}

/// A card-shaped placeholder for a list that is loading for the first time.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => const AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: AppSpace.xl, width: AppSize.touchTarget * 4),
        Gap.sm(),
        Skeleton(height: AppSpace.lg, width: AppSize.touchTarget * 3),
        Gap.lg(),
        Skeleton(height: AppSpace.xl, width: AppSize.touchTarget * 2),
      ],
    ),
  );
}

/// A section title inside a screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.md),
      child: Text(title, style: context.text.h3),
    ),
  );
}
