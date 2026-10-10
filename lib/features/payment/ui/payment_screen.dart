import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/features/payment/state/payment_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({required this.bookingId, super.key});

  final String bookingId;

  static String _refusal(AppLocalizations l10n, ApiException failure) =>
      switch (failure.code) {
        ApiErrorCode.paymentNotRequired => l10n.errPaymentNotRequired,
        ApiErrorCode.paymentAlreadyCompleted => l10n.errPaymentAlreadyCompleted,
        ApiErrorCode.bookingExpired ||
        ApiErrorCode.invalidBookingState ||
        ApiErrorCode.notFound => l10n.errBookingExpired,
        ApiErrorCode.approvalRequired => l10n.errApprovalRequired,
        ApiErrorCode.paymentProviderUnavailable =>
          l10n.errPaymentProviderUnavailable,
        _ => l10n.describe(failure),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final provider = paymentProvider(bookingId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final order = state.order;
    final amount = order == null ? null : formatMoney(order.total);
    final failure = state.failure;

    final viewBooking = SecondaryButton(
      label: l10n.paymentViewBooking,
      onPressed: () => context.pop(),
    );
    final tryAgain = PrimaryButton(
      label: l10n.actionTryAgain,
      onPressed: notifier.start,
    );

    final (Widget body, Widget? bottom) = switch (state.stage) {
      PaymentStage.starting => (_Waiting(l10n.paymentStarting), null),
      PaymentStage.inCheckout => (_Waiting(l10n.paymentInCheckout), null),
      PaymentStage.confirming => (_Waiting(l10n.paymentConfirming), null),
      PaymentStage.readyToSimulate => (
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (amount != null)
              Text(
                amount,
                style: context.text.display,
                textAlign: TextAlign.center,
              ),
            const Gap.lg(),
            AppBanner(tone: StatusTone.info, message: l10n.paymentTestNote),
            const Gap.xl(),
            PrimaryButton(
              label: l10n.paymentSimulateSuccess,
              onPressed: () => notifier.simulate(succeed: true),
            ),
            const Gap.sm(),
            SecondaryButton(
              label: l10n.paymentSimulateFailure,
              onPressed: () => notifier.simulate(succeed: false),
            ),
          ],
        ),
        null,
      ),
      PaymentStage.succeeded => (
        _Result(
          icon: Icons.check_circle_outline,
          color: colors.success.solid,
          title: l10n.paymentSucceededTitle,
          body: amount == null
              ? l10n.errPaymentAlreadyCompleted
              : l10n.paymentSucceededBody(amount),
        ),
        PrimaryButton(
          label: l10n.paymentViewBooking,
          onPressed: () => context.pop(),
        ),
      ),
      PaymentStage.failed => (
        _Result(
          icon: Icons.error_outline,
          color: colors.danger.solid,
          title: l10n.paymentFailedTitle,
          body: l10n.paymentFailedBody,
          footer: viewBooking,
        ),
        tryAgain,
      ),
      PaymentStage.notCompleted => (
        _Result(
          icon: Icons.info_outline,
          color: colors.textSecondary,
          title: l10n.paymentNotCompletedTitle,
          body: l10n.paymentNotCompletedBody,
          footer: viewBooking,
        ),
        tryAgain,
      ),
      // No "Try again" here on purpose: the first payment may still land,
      // and a second one would charge the customer twice.
      PaymentStage.stillPending => (
        _Result(
          icon: Icons.schedule_outlined,
          color: colors.warning.solid,
          title: l10n.paymentPendingTitle,
          body: l10n.paymentPendingBody,
        ),
        PrimaryButton(
          label: l10n.paymentViewBooking,
          onPressed: () => context.pop(),
        ),
      ),
      PaymentStage.unavailable => (
        _Result(
          icon: Icons.block_outlined,
          color: colors.textSecondary,
          title: l10n.paymentUnavailableTitle,
          body: l10n.paymentUnavailableBody,
        ),
        PrimaryButton(
          label: l10n.paymentViewBooking,
          onPressed: () => context.pop(),
        ),
      ),
      PaymentStage.refused => (
        _Result(
          icon: Icons.error_outline,
          color: colors.danger.solid,
          title: l10n.errorTitle,
          body: failure == null ? l10n.errorGeneric : _refusal(l10n, failure),
          footer: viewBooking,
        ),
        failure != null && failure.isTransient ? tryAgain : null,
      ),
    };

    return AppScaffold(
      title: l10n.paymentTitle,
      body: Center(child: body),
      bottom: bottom,
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: AppSize.icon,
          child: CircularProgressIndicator(
            strokeWidth: AppSize.focusBorderWidth,
          ),
        ),
        const Gap.lg(),
        Text(
          message,
          style: context.text.body.copyWith(
            color: context.colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;

    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppSize.touchTarget, color: color),
          ),
          const Gap.lg(),
          Text(title, style: context.text.h2, textAlign: TextAlign.center),
          const Gap.sm(),
          Text(
            body,
            style: context.text.body.copyWith(
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (footer != null) ...[const Gap.xl(), footer],
        ],
      ),
    );
  }
}
