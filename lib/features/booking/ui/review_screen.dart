import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/state/booking_draft.dart';
import 'package:app/features/booking/state/create_booking_notifier.dart';
import 'package:app/features/booking/ui/price_breakdown.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Everything the customer is committing to, on one screen, before the
/// one action that commits.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({required this.draft, super.key});

  final BookingDraft draft;

  static String _failureText(AppLocalizations l10n, ApiException failure) =>
      switch (failure.code) {
        ApiErrorCode.slotUnavailable => l10n.errSlotUnavailable,
        ApiErrorCode.quoteExpired => l10n.errQuoteExpired,
        ApiErrorCode.paymentModeNotSupported => l10n.errPaymentModeNotSupported,
        ApiErrorCode.outsideOperatingHours => l10n.errOutsideHours,
        ApiErrorCode.invalidBookingWindow ||
        ApiErrorCode.validationFailed => l10n.errInvalidWindow,
        ApiErrorCode.vehicleTypeNotSupported => l10n.errVehicleNotSupported,
        ApiErrorCode.parkingLotNotBookable => l10n.errNotBookable,
        _ => l10n.describe(failure),
      };

  /// Failures that mean the choice itself must change, not be retried.
  static bool _needsNewChoice(ApiException failure) => switch (failure.code) {
    ApiErrorCode.slotUnavailable ||
    ApiErrorCode.quoteExpired ||
    ApiErrorCode.outsideOperatingHours ||
    ApiErrorCode.invalidBookingWindow => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final provider = createBookingProvider(draft);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final quote = draft.quote;
    final failure = state.failure;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final needsApproval = quote.bookingMode == BookingMode.ownerApproval;

    ref.listen(provider, (previous, next) {
      final created = next.created;
      if (created != null && previous?.created == null) {
        // Moves to the booking in the Bookings tab, so going back does not
        // return to this form.
        context.go(Routes.booking(created.id));
      }
    });

    return AppScaffold(
      title: l10n.reviewTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.md(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draft.lot.name, style: text.h3),
                const Gap.md(),
                _Row(l10n.reviewVehicle, draft.vehicleTypeName),
                const Gap.sm(),
                _Row(
                  l10n.reviewArrive,
                  FacilityTime.dayAndTime(
                    draft.startAt,
                    quote.timezone,
                    locale,
                  ),
                ),
                const Gap.sm(),
                _Row(
                  l10n.reviewLeave,
                  FacilityTime.dayAndTime(draft.endAt, quote.timezone, locale),
                ),
              ],
            ),
          ),
          const Gap.md(),
          PriceBreakdown(lines: quote.lines, total: quote.total),
          SectionHeader(l10n.reviewPayment),
          if (quote.acceptsOnsitePayment)
            _PaymentOption(
              title: l10n.payOnSite,
              hint: l10n.payOnSiteHint,
              isSelected: state.paymentMode == PaymentMode.onSite,
              onTap: () => notifier.selectPaymentMode(PaymentMode.onSite),
            ),
          if (quote.acceptsOnsitePayment && quote.acceptsOnlinePayment)
            const Gap.sm(),
          if (quote.acceptsOnlinePayment)
            _PaymentOption(
              title: l10n.payOnline,
              hint: l10n.payOnlineHint,
              isSelected: state.paymentMode == PaymentMode.online,
              onTap: () => notifier.selectPaymentMode(PaymentMode.online),
            ),
          if (state.paymentMode == PaymentMode.online) ...[
            const Gap.sm(),
            AppBanner(
              tone: StatusTone.warning,
              message: l10n.reviewOnlineNotReady,
            ),
          ],
          const Gap.lg(),
          AppBanner(
            tone: needsApproval ? StatusTone.warning : StatusTone.info,
            message: needsApproval
                ? l10n.reviewApprovalNote
                : l10n.reviewInstantNote,
          ),
          const Gap.sm(),
          Text(
            l10n.reviewCancelNote,
            style: text.bodySmall.copyWith(color: colors.textSecondary),
          ),
          if (failure != null) ...[
            const Gap.md(),
            AppBanner(
              tone: StatusTone.danger,
              message: _failureText(l10n, failure),
            ),
            if (_needsNewChoice(failure))
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextAction(
                  label: l10n.actionBackToTime,
                  onPressed: () => context.pop(),
                ),
              ),
          ],
          const Gap.lg(),
        ],
      ),
      bottom: PrimaryButton(
        label: needsApproval ? l10n.reviewSendRequest : l10n.reviewBook,
        isLoading: state.isSubmitting,
        onPressed: notifier.submit,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodySmall.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const Gap.lg(),
        Expanded(
          child: Text(
            value,
            style: context.text.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.title,
    required this.hint,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      button: true,
      child: Material(
        color: isSelected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(
            color: isSelected ? colors.primary : colors.borderControl,
            width: isSelected ? AppSize.focusBorderWidth : AppSize.borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: AppSize.icon,
                    color: isSelected ? colors.primary : colors.borderControl,
                  ),
                ),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        hint,
                        style: text.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
