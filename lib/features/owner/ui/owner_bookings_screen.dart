import 'package:app/app/routes.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_filter_chip.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/cursor_list_view.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/ui/booking_status_chip.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:app/features/owner/ui/owner_common.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OwnerBookingsScreen extends ConsumerWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(ownerBookingsProvider);
    final notifier = ref.read(ownerBookingsProvider.notifier);
    final filter = ref.watch(ownerBookingFilterProvider);

    final filters = <(BookingStatus?, String)>[
      (BookingStatus.pendingApproval, l10n.ownerFilterRequests),
      (BookingStatus.confirmed, l10n.ownerFilterConfirmed),
      (BookingStatus.completed, l10n.ownerFilterCompleted),
      (null, l10n.ownerFilterAll),
    ];
    final onRequests = filter == BookingStatus.pendingApproval;

    return AppScaffold(
      title: l10n.ownerTabBookings,
      actions: const [ExitOwnerAreaAction()],
      scrollable: false,
      body: CursorListView<Booking>(
        state: state,
        onRefresh: notifier.load,
        onLoadMore: notifier.loadMore,
        errorText: (failure) => ownerAccessText(l10n, failure),
        header: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, (status, label)) in filters.indexed) ...[
                if (index > 0) const Gap.sm(),
                AppFilterChip(
                  label: label,
                  isSelected: filter == status,
                  onPressed: () =>
                      ref.read(ownerBookingFilterProvider.notifier).state =
                          status,
                ),
              ],
            ],
          ),
        ),
        empty: EmptyState(
          icon: Icons.event_available_outlined,
          title: onRequests
              ? l10n.ownerRequestsEmptyTitle
              : l10n.ownerBookingsEmptyTitle,
          body: onRequests
              ? l10n.ownerRequestsEmptyBody
              : l10n.ownerBookingsEmptyBody,
        ),
        itemBuilder: (context, booking) => _OwnerBookingCard(
          booking: booking,
          onTap: () => context.push(Routes.ownerBooking(booking.id)),
        ),
      ),
    );
  }
}

class _OwnerBookingCard extends StatelessWidget {
  const _OwnerBookingCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Semantics(
      button: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(booking.reference, style: text.price)),
                BookingStatusChip(booking: booking),
              ],
            ),
            const Gap.sm(),
            Text(
              booking.parkingLot.name,
              style: text.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap.xs(),
            Text(
              '${FacilityTime.dayAndTime(booking.startAt, booking.timezone, locale)} – '
              '${FacilityTime.time(booking.endAt, booking.timezone, locale)}'
              ' · ${formatMoney(booking.total)}',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
