import 'package:app/core/money/money.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_segmented_control.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/gate/data/extra_time_payment.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Shows the booking a check-out code belongs to, as the API verified it,
/// and asks the person at the gate to confirm. When extra time is due they
/// say how it was paid; null means they backed out.
Future<CheckOutChoice?> confirmCheckOut(
  BuildContext context,
  Booking booking,
) => showModalBottomSheet<CheckOutChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => CheckOutConfirmSheet(booking: booking),
);

class CheckOutConfirmSheet extends StatefulWidget {
  const CheckOutConfirmSheet({required this.booking, super.key});

  final Booking booking;

  @override
  State<CheckOutConfirmSheet> createState() => _CheckOutConfirmSheetState();
}

class _CheckOutConfirmSheetState extends State<CheckOutConfirmSheet> {
  ExtraTimeMethod? _method;
  bool _collected = false;
  ExtraTimeMethod? _bookingMethod;
  bool _bookingCollected = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final booking = widget.booking;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String at(DateTime instant) =>
        FacilityTime.dayAndTime(instant, booking.timezone, locale);
    final overstay = booking.overstay;
    final bookingDue = booking.paymentDueAtFacility;
    final blocked = booking.onlinePaymentMissing;
    final extraReady = overstay == null || (_method != null && _collected);
    final bookingReady =
        !bookingDue || (_bookingMethod != null && _bookingCollected);

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
          const Gap.md(),
          Flexible(
            child: Text(value, style: text.body, textAlign: TextAlign.end),
          ),
        ],
      ),
    );

    // Scrolls on small screens; the sheet never overflows.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.checkOutConfirmTitle, style: text.h2),
          const Gap.md(),
          line(l10n.bookingReference, booking.reference),
          line(l10n.checkOutConfirmFacility, booking.parkingLot.name),
          line(
            l10n.checkOutConfirmBooked,
            '${at(booking.startAt)} – ${FacilityTime.time(booking.endAt, booking.timezone, locale)}',
          ),
          if (booking.checkedInAt case final arrived?)
            line(l10n.checkOutConfirmCheckedIn, at(arrived)),
          if (booking.spaceLabel case final bay?) line(l10n.bookingSpace, bay),
          if (blocked) ...[
            const Gap.sm(),
            AppBanner(
              tone: StatusTone.danger,
              message: l10n.checkOutOnlineUnpaid,
            ),
          ],
          if (bookingDue) ...[
            const Gap.sm(),
            AppBanner(
              tone: StatusTone.warning,
              message: l10n.checkOutBookingDue(formatMoney(booking.total)),
            ),
            const Gap.md(),
            Text(l10n.checkOutBookingPaidBy, style: text.label),
            const Gap.sm(),
            AppSegmentedControl<ExtraTimeMethod?>(
              key: const ValueKey('booking-payment-method'),
              segments: [
                (ExtraTimeMethod.cash, l10n.paidByCash),
                (ExtraTimeMethod.upi, l10n.paidByUpi),
                (ExtraTimeMethod.card, l10n.paidByCard),
              ],
              selected: _bookingMethod,
              onChanged: (method) => setState(() => _bookingMethod = method),
            ),
            const Gap.sm(),
            // Never marked paid automatically: the person confirms the
            // money is actually in hand.
            CheckboxListTile(
              key: const ValueKey('booking-payment-collected'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _bookingCollected,
              onChanged: (value) =>
                  setState(() => _bookingCollected = value ?? false),
              title: Text(
                l10n.checkOutBookingCollectedConfirm(
                  formatMoney(booking.total),
                ),
                style: text.body,
              ),
            ),
          ],
          if (overstay != null) ...[
            const Gap.sm(),
            AppBanner(
              tone: StatusTone.warning,
              message: l10n.checkOutOverstay(
                overstay.minutes,
                formatMoney(Money(overstay.totalAmount, booking.currency)),
              ),
            ),
            const Gap.md(),
            Text(l10n.checkOutPaidBy, style: text.label),
            const Gap.sm(),
            AppSegmentedControl<ExtraTimeMethod?>(
              segments: [
                (ExtraTimeMethod.cash, l10n.paidByCash),
                (ExtraTimeMethod.upi, l10n.paidByUpi),
                (ExtraTimeMethod.card, l10n.paidByCard),
              ],
              selected: _method,
              onChanged: (method) => setState(() => _method = method),
            ),
            const Gap.sm(),
            // Choosing a method is not enough: the person confirms the
            // money is actually in hand.
            CheckboxListTile(
              key: const ValueKey('extra-time-collected'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _collected,
              onChanged: (value) => setState(() => _collected = value ?? false),
              title: Text(
                l10n.checkOutCollectedConfirm(
                  formatMoney(Money(overstay.totalAmount, booking.currency)),
                ),
                style: text.body,
              ),
            ),
          ],
          const Gap.lg(),
          PrimaryButton(
            label: overstay == null && !bookingDue
                ? l10n.checkOutConfirmAction
                : l10n.checkOutCollectedAction,
            // Nothing is marked paid until a method is chosen and the
            // money confirmed; an unpaid online booking can't leave.
            onPressed: blocked || !extraReady || !bookingReady
                ? null
                : () => Navigator.of(context).pop(
                    CheckOutChoice(
                      method: overstay == null ? null : _method,
                      expectedAmount: overstay?.totalAmount.toStringAsFixed(2),
                      bookingMethod: bookingDue ? _bookingMethod : null,
                      bookingAmount: bookingDue
                          ? booking.totalAmount.toStringAsFixed(2)
                          : null,
                    ),
                  ),
          ),
          const Gap.sm(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelKeep),
          ),
        ],
      ),
    );
  }
}
