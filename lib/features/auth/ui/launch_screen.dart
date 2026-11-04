import 'package:app/app/routes.dart';
import 'package:app/core/config/app_identity.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_logo.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The first screen for someone who is not signed in.
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return AppScaffold(
      onNavy: true,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(
            variant: AppLogoVariant.fullOnDark,
            height: AppSize.touchTarget * 2,
          ),
          const Gap.xxl(),
          Text(
            l10n.launchTitle(appDisplayName),
            style: context.text.display.copyWith(color: colors.onNavy),
          ),
          const Gap.md(),
          Text(
            l10n.launchTagline,
            style: context.text.body.copyWith(color: colors.onNavy),
          ),
          const Gap.xl(),
          Text(
            l10n.launchAccountHint,
            style: context.text.bodySmall.copyWith(color: colors.onNavy),
          ),
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.launchGetStarted,
        onPressed: () => context.push(Routes.phone),
      ),
    );
  }
}
