import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/money/money.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/core/widgets/title_with_status.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/state/booking_details_notifier.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:app/features/booking/ui/booking_status_chip.dart';
import 'package:app/features/booking/ui/check_in_code_card.dart';
import 'package:app/features/booking/ui/live_booking_refresh.dart';
import 'package:app/features/booking/ui/price_breakdown.dart';
import 'package:app/features/booking/ui/rate_booking_card.dart';
import 'package:app/features/booking/ui/rating_sheet.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookingDetailsScreen extends ConsumerWidget {
  const BookingDetailsScreen({required this.id, super.key});

  final String id;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final l10n = context.l10n;
    final isRequest = booking.status == BookingStatus.pendingApproval;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.cancelConfirmTitle,
      body: switch ((booking.paymentMode, booking.refundIfCancelledNow)) {
        // A paid booking: say exactly what happens to the money.
        (PaymentMode.online, true)
            when booking.status == BookingStatus.confirmed =>
          l10n.cancelConfirmBodyRefund,
        (PaymentMode.online, false)
            when booking.status == BookingStatus.confirmed =>
          l10n.cancelConfirmBodyNoRefund,
        (PaymentMode.online, _) => l10n.cancelConfirmBodyOnline,
        _ => l10n.cancelConfirmBodyOnSite,
      },
      confirmLabel: isRequest ? l10n.bookingCancelRequest : l10n.bookingCancel,
      cancelLabel: l10n.cancelKeep,
      isDestructive: true,
    );
    if (confirmed) {
      await ref.read(bookingDetailsProvider(id).notifier).cancel();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final details = ref.watch(bookingDetailsProvider(id));

    // Checked out at the gate while this page is open: ask for a rating
    // straight away, once. Only a change seen here opens it, so opening the
    // booking later (from Past bookings) never shows it again.
    ref.listen(bookingDetailsProvider(id), (previous, next) {
      final before = previous?.valueOrNull?.booking;
      final after = next.valueOrNull?.booking;
      if (before == null || after == null) return;
      // Checked in or out at the gate: the Bookings tabs move it too.
      if (before.status != after.status) ref.invalidate(bookingsProvider);
      if (before.status != BookingStatus.completed &&
          after.status == BookingStatus.completed &&
          after.myRating == null) {
        showRatingSheet(context, after);
      }
    });

    return details.when(
      loading: () => AppScaffold(
        title: l10n.bookingTitle,
        body: const Column(
          children: [Gap.lg(), SkeletonCard(), Gap.md(), SkeletonCard()],
        ),
      ),
      error: (error, _) {
        final failure = error is ApiException
            ? error
            : const ApiException(code: ApiErrorCode.unknown);
        return AppScaffold(
          title: l10n.bookingTitle,
          body: Center(
            child: ErrorState(
              failure: failure,
              message: failure.code == ApiErrorCode.notFound
                  ? l10n.bookingNotFound
                  : null,
              onRetry: () => ref.invalidate(bookingDetailsProvider(id)),
            ),
          ),
        );
      },
      data: (state) {
        final booking = state.booking;
        final cancelFailure = state.cancelFailure;
        final isRequest = booking.status == BookingStatus.pendingApproval;

        return AppScaffold(
          title: l10n.bookingTitle,
          scrollable: false,
          // The amount is on the button: paying is never an unlabelled tap.
          bottom: booking.paymentRequired
              ? PrimaryButton(
                  label: l10n.payAmount(formatMoney(booking.total)),
                  onPressed: () => context.push(Routes.pay(booking.id)),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: ref.read(bookingDetailsProvider(id).notifier).refresh,
            child: ListView(
              children: [
                // While a gate code is on screen, the booking is re-read
                // every few seconds, so check-in and check-out show at once.
                LiveBookingRefresh(
                  active:
                      booking.checkInCode != null ||
                      booking.checkOutCode != null,
                  onTick: ref.read(bookingDetailsProvider(id).notifier).refresh,
                ),
                const Gap.md(),
                _Body(booking: booking),
                if (booking.status == BookingStatus.completed) ...[
                  const Gap.lg(),
                  RateBookingCard(booking: booking),
                ],
                if (cancelFailure != null) ...[
                  const Gap.md(),
                  AppBanner(
                    tone: StatusTone.danger,
                    message: switch (cancelFailure.code) {
                      ApiErrorCode.cancellationNotAllowed ||
                      ApiErrorCode.invalidBookingState =>
                        l10n.errCancellationNotAllowed,
                      _ => l10n.describe(cancelFailure),
                    },
                  ),
                ],
                if (state.canCancel) ...[
                  const Gap.lg(),
                  if (state.isCancelling)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpace.md),
                        child: SizedBox.square(
                          dimension: AppSize.spinner,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSize.focusBorderWidth,
                          ),
                        ),
                      ),
                    )
                  else
                    TextAction(
                      label: isRequest
                          ? l10n.bookingCancelRequest
                          : l10n.bookingCancel,
                      isDestructive: true,
                      onPressed: () => _cancel(context, ref, booking),
                    ),
                ],
                const Gap.xl(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking});

  final Booking booking;

  /// The sentence that tells the customer where this booking stands and
  /// what, if anything, they should do.
  static (StatusTone, String) _banner(
    AppLocalizations l10n,
    Booking booking,
    String locale,
  ) {
    String at(DateTime instant) =>
        FacilityTime.time(instant, booking.timezone, locale);
    final approvalDeadline = booking.approvalDeadlineAt;
    final paymentDeadline = booking.paymentDeadlineAt;

    return switch (booking.status) {
      BookingStatus.pendingApproval => (
        StatusTone.warning,
        approvalDeadline == null
            ? l10n.bannerPendingApprovalNoTime
            : l10n.bannerPendingApproval(at(approvalDeadline)),
      ),
      BookingStatus.awaitingPayment => (
        StatusTone.warning,
        paymentDeadline == null
            ? l10n.bannerAwaitingPaymentNoTime
            : l10n.bannerAwaitingPayment(at(paymentDeadline)),
      ),
      BookingStatus.parked => (
        StatusTone.success,
        l10n.bannerParkedShowCode(at(booking.endAt)),
      ),
      BookingStatus.confirmed when booking.isCheckedIn => (
        StatusTone.success,
        l10n.bannerParked(at(booking.endAt)),
      ),
      BookingStatus.confirmed => (
        StatusTone.success,
        booking.checkInCode == null
            ? l10n.bannerConfirmed
            : l10n.bannerConfirmedWithCode,
      ),
      BookingStatus.completed => (StatusTone.neutral, l10n.bannerCompleted),
      BookingStatus.cancelled => (
        StatusTone.neutral,
        switch (booking.refundEligible) {
          true => l10n.bannerCancelledRefund,
          false when booking.paymentMode == PaymentMode.online =>
            l10n.bannerCancelledNoRefund,
          _ => l10n.bannerCancelled,
        },
      ),
      BookingStatus.rejected => (StatusTone.danger, l10n.bannerRejected),
      BookingStatus.expired => (StatusTone.neutral, l10n.bannerExpired),
      BookingStatus.noShow => (StatusTone.warning, l10n.bannerNoShow),
      BookingStatus.unknown => (StatusTone.neutral, l10n.statusAwaitingUpdate),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (tone, message) = _banner(l10n, booking, locale);
    final isOpen = switch (booking.status) {
      BookingStatus.pendingApproval ||
      BookingStatus.awaitingPayment ||
      BookingStatus.confirmed ||
      BookingStatus.parked => true,
      _ => false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The banner follows the status: a new state cross-fades in.
        AnimatedSwitcher(
          duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
          child: AppBanner(
            key: ValueKey(message),
            tone: tone,
            message: message,
          ),
        ),
        const Gap.md(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitleWithStatus(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.bookingReference,
                      style: text.label.copyWith(color: colors.textSecondary),
                    ),
                    SelectableText(booking.reference, style: text.h2),
                  ],
                ),
                status: BookingStatusChip(booking: booking),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Divider(),
              ),
              Text(booking.parkingLot.name, style: text.h3),
              const Gap.xs(),
              Text(
                '${FacilityTime.dayAndTime(booking.startAt, booking.timezone, locale)} – '
                '${FacilityTime.dayAndTime(booking.endAt, booking.timezone, locale)}',
                style: text.bodySmall.copyWith(color: colors.textSecondary),
              ),
              if (booking.spaceLabel case final bay?) ...[
                const Gap.xs(),
                Text(
                  '${l10n.bookingSpace} $bay',
                  style: text.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        if (booking.checkInCode case final code?) ...[
          const Gap.md(),
          // The code is revealed, not just drawn: it is what to show next.
          Reveal(
            child: CheckInCodeCard(code: code, bookingId: booking.id),
          ),
        ],
        if (booking.overstay case final extra?) ...[
          const Gap.md(),
          AppBanner(
            tone: StatusTone.warning,
            message: booking.isCheckedIn
                ? l10n.overstayWhileParked(
                    extra.minutes,
                    formatMoney(Money(extra.totalAmount, booking.currency)),
                  )
                : l10n.overstayCharged(
                    formatMoney(Money(extra.totalAmount, booking.currency)),
                  ),
          ),
        ],
        if (booking.checkOutCode case final code?) ...[
          const Gap.md(),
          Reveal(
            child: CheckInCodeCard(
              code: code,
              bookingId: booking.id,
              checkOut: true,
            ),
          ),
        ],
        const Gap.md(),
        PriceBreakdown(
          lines: booking.priceLines,
          total: booking.total,
          charges: booking.charges,
        ),
        if (isOpen && booking.paymentMode == PaymentMode.onSite) ...[
          const Gap.md(),
          AppBanner(
            tone: StatusTone.info,
            icon: Icons.payments_outlined,
            message: l10n.payAtFacilityDue(formatMoney(booking.total)),
          ),
        ],
      ],
    );
  }
}
