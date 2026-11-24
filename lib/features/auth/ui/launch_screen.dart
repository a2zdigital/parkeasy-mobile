import 'package:app/app/routes.dart';
import 'package:app/core/config/app_identity.dart';
import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_logo.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The first screen for someone who is not signed in: what the app does in
/// three lines, then the two ways in.
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final points = [
      (Icons.near_me_outlined, l10n.launchPointNearby),
      (Icons.sell_outlined, l10n.launchPointPrice),
      (Icons.qr_code_2, l10n.launchPointCheckIn),
    ];

    return AppScaffold(
      onNavy: true,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeSlideIn(
            child: AppLogo(
              variant: AppLogoVariant.fullOnDark,
              height: AppSize.touchTarget * 1.5,
            ),
          ),
          const Gap.xxl(),
          FadeSlideIn(
            index: 1,
            child: Text(
              l10n.launchTitle(appDisplayName),
              style: context.text.display.copyWith(color: colors.onNavy),
            ),
          ),
          const Gap.sm(),
          FadeSlideIn(
            index: 2,
            child: Text(
              l10n.launchTagline,
              style: context.text.body.copyWith(
                color: colors.onNavy.withValues(alpha: 0.8),
              ),
            ),
          ),
          const Gap.xl(),
          for (final (i, (icon, label)) in points.indexed)
            FadeSlideIn(
              index: 3 + i,
              child: _Point(icon: icon, label: label),
            ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: l10n.launchLogIn,
            onPressed: () => context.push(Routes.phone),
          ),
          const Gap.sm(),
          SecondaryButton(
            label: l10n.launchCreateAccount,
            onPressed: () => context.push(Routes.registrationRole),
          ),
          TextAction(
            label: l10n.launchBrowse,
            onNavy: true,
            onPressed: () => context.go(Routes.explore),
          ),
          Text(
            l10n.launchAccountHint,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(
              color: colors.onNavy.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: AppSize.iconTile,
              height: AppSize.iconTile,
              decoration: BoxDecoration(
                color: colors.onNavy.withValues(alpha: 0.1),
                borderRadius: AppRadius.smallAll,
              ),
              child: Icon(
                icon,
                size: AppSize.iconSmall,
                color: colors.accentTeal,
              ),
            ),
          ),
          const Gap.md(),
          Expanded(
            child: Text(
              label,
              style: context.text.body.copyWith(color: colors.onNavy),
            ),
          ),
        ],
      ),
    );
  }
}
