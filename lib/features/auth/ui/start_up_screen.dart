import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_logo.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown while the stored sign-in is checked, and when that check could
/// not reach the API.
class StartUpScreen extends ConsumerWidget {
  const StartUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    return AppScaffold(
      onNavy: true,
      body: Center(
        child: switch (session) {
          SessionRestoreFailed(:final failure) => ErrorState(
            failure: failure,
            onNavy: true,
            onRetry: () =>
                ref.read(sessionControllerProvider.notifier).restore(),
          ),
          _ => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(
                variant: AppLogoVariant.mark,
                height: AppSize.touchTarget * 2,
              ),
              const Gap.xl(),
              Semantics(
                label: context.l10n.startingUp,
                child: SizedBox.square(
                  dimension: AppSize.icon,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSize.focusBorderWidth,
                    color: context.colors.onNavy,
                  ),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
