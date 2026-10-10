import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/money/money_format.dart';
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
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/ui/booking_status_chip.dart';
import 'package:app/features/booking/ui/price_breakdown.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_booking_notifier.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A booking as the facility's owner sees it. It shows the reference and
/// the terms, never who the customer is.
class OwnerBookingScreen extends ConsumerWidget {
  const OwnerBookingScreen({required this.id, super.key});

  final String id;

  static String _failureText(AppLocalizations l10n, ApiException failure) =>
      switch (failure.code) {
        ApiErrorCode.checkInNotAllowed => l10n.errCheckInNotAllowed,
        ApiErrorCode.checkOutNotAllowed => l10n.errCheckOutNotAllowed,
        ApiErrorCode.invalidBookingState => l10n.errInvalidBookingState,
        ApiErrorCode.approvalExpired => l10n.errApprovalExpired,
        ApiErrorCode.onsiteCollectionNotAllowed => l10n.errCollectionNotAllowed,
        ApiErrorCode.onsiteCollectionExists => l10n.errCollectionExists,
        _ => ownerAccessText(l10n, failure) ?? l10n.describe(failure),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = ownerBookingProvider(id);
    final details = ref.watch(provider);

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
                  : ownerAccessText(l10n, failure),
              onRetry: () => ref.invalidate(provider),
            ),
          ),
        );
      },
      data: (state) {
        final notifier = ref.read(provider.notifier);
        final booking = state.booking;
        final collection = state.collection;
        final failure = state.failure;
        final text = context.text;
        final colors = context.colors;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final checkedInAt = booking.checkedInAt;
        final total = formatMoney(booking.total);

        Future<void> confirmThen(
          Future<void> Function() action, {
          required String title,
          required String body,
          required String confirm,
          bool destructive = false,
        }) async {
          final confirmed = await showConfirmDialog(
            context,
            title: title,
            body: body,
            confirmLabel: confirm,
            cancelLabel: l10n.actionCancel,
            isDestructive: destructive,
          );
          if (confirmed) await action();
        }

        // The one action that moves this booking forward, if there is one.
        final Widget? primary;
        if (state.canAnswerRequest) {
          primary = PrimaryButton(
            label: l10n.ownerApprove,
            isLoading: state.isBusy,
            onPressed: () => notifier.act(OwnerBookingAction.approve),
          );
        } else if (state.canCheckIn) {
          primary = PrimaryButton(
            label: l10n.ownerCheckIn,
            isLoading: state.isBusy,
            onPressed: () => notifier.act(OwnerBookingAction.checkIn),
          );
        } else if (state.canCheckOut) {
          primary = PrimaryButton(
            label: l10n.ownerCheckOut,
            isLoading: state.isBusy,
            onPressed: () => confirmThen(
              () => notifier.act(OwnerBookingAction.checkOut),
              title: l10n.ownerCheckOutConfirmTitle,
              body: l10n.ownerCheckOutConfirmBody,
              confirm: l10n.ownerCheckOut,
            ),
          );
        } else {
          primary = null;
        }

        return AppScaffold(
          title: l10n.bookingTitle,
          scrollable: false,
          bottom: primary,
          body: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              children: [
                const Gap.md(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BookingStatusChip(booking: booking),
                ),
                const Gap.md(),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bookingReference,
                        style: text.label.copyWith(color: colors.textSecondary),
                      ),
                      SelectableText(booking.reference, style: text.h2),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpace.md),
                        child: Divider(),
                      ),
                      Text(booking.parkingLot.name, style: text.h3),
                      const Gap.xs(),
                      Text(
                        '${FacilityTime.dayAndTime(booking.startAt, booking.timezone, locale)} – '
                        '${FacilityTime.dayAndTime(booking.endAt, booking.timezone, locale)}',
                        style: text.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const Gap.sm(),
                      Text(
                        booking.paymentMode == PaymentMode.onSite
                            ? l10n.ownerPaysAtFacility
                            : l10n.ownerPaidOnline,
                        style: text.bodySmall,
                      ),
                      if (checkedInAt != null) ...[
                        const Gap.xs(),
                        Text(
                          l10n.ownerCheckedInAt(
                            FacilityTime.time(
                              checkedInAt,
                              booking.timezone,
                              locale,
                            ),
                          ),
                          style: text.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap.md(),
                PriceBreakdown(lines: booking.priceLines, total: booking.total),
                if (collection != null) ...[
                  const Gap.md(),
                  AppBanner(
                    tone: collection.collection == null
                        ? StatusTone.info
                        : StatusTone.success,
                    icon: Icons.payments_outlined,
                    message: collection.collection == null
                        ? l10n.ownerDueAtFacility(formatMoney(collection.due))
                        : l10n.ownerCollected(formatMoney(collection.due)),
                  ),
                ],
                if (failure != null) ...[
                  const Gap.md(),
                  AppBanner(
                    tone: StatusTone.danger,
                    message: _failureText(l10n, failure),
                  ),
                ],
                if (state.canRecordPayment) ...[
                  const Gap.md(),
                  SecondaryButton(
                    label: l10n.ownerRecordPayment(total),
                    isLoading: state.isBusy && primary == null,
                    onPressed: state.isBusy
                        ? null
                        : () => confirmThen(
                            notifier.recordPayment,
                            title: l10n.ownerRecordConfirmTitle,
                            body: l10n.ownerRecordConfirmBody(total),
                            confirm: l10n.ownerRecordConfirm,
                          ),
                  ),
                ],
                if (state.canAnswerRequest) ...[
                  const Gap.sm(),
                  TextAction(
                    label: l10n.ownerReject,
                    isDestructive: true,
                    onPressed: state.isBusy
                        ? null
                        : () => confirmThen(
                            () => notifier.act(OwnerBookingAction.reject),
                            title: l10n.ownerRejectConfirmTitle,
                            body: l10n.ownerRejectConfirmBody,
                            confirm: l10n.ownerReject,
                            destructive: true,
                          ),
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
