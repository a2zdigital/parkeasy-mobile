import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The one place a booking's status becomes a label, a tone and an icon.
/// Mapping: docs/design/ux-conventions.md.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({required this.booking, super.key});

  final Booking booking;

  static (String, StatusTone, IconData) describe(
    AppLocalizations l10n,
    Booking booking,
  ) => switch (booking.status) {
    BookingStatus.pendingApproval => (
      l10n.statusPendingApproval,
      StatusTone.warning,
      Icons.schedule_outlined,
    ),
    BookingStatus.awaitingPayment => (
      l10n.statusAwaitingPayment,
      StatusTone.warning,
      Icons.credit_card_outlined,
    ),
    BookingStatus.confirmed when booking.isCheckedIn => (
      l10n.statusParked,
      StatusTone.success,
      Icons.local_parking_outlined,
    ),
    BookingStatus.confirmed => (
      l10n.statusConfirmed,
      StatusTone.success,
      Icons.check_circle_outline,
    ),
    BookingStatus.completed => (
      l10n.statusCompleted,
      StatusTone.neutral,
      Icons.flag_outlined,
    ),
    BookingStatus.cancelled => (
      l10n.statusCancelled,
      StatusTone.danger,
      Icons.cancel_outlined,
    ),
    BookingStatus.rejected => (
      l10n.statusRejected,
      StatusTone.danger,
      Icons.block_outlined,
    ),
    BookingStatus.expired => (
      l10n.statusExpired,
      StatusTone.neutral,
      Icons.timer_off_outlined,
    ),
    BookingStatus.noShow => (
      l10n.statusNoShow,
      StatusTone.neutral,
      Icons.event_busy_outlined,
    ),
    // A status added to the API after this build: shown as it is, neutrally.
    BookingStatus.unknown => (
      l10n.statusAwaitingUpdate,
      StatusTone.neutral,
      Icons.help_outline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = describe(context.l10n, booking);
    return StatusChip(tone: tone, label: label, icon: icon);
  }
}
