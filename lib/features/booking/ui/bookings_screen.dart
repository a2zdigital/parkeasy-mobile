import 'package:app/app/routes.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:app/features/booking/ui/booking_status_chip.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(bookingsProvider);
    final notifier = ref.read(bookingsProvider.notifier);
    final failure = state.failure;
    final loadMoreFailure = state.loadMoreFailure;

    final Widget content;
    if (state.isLoading) {
      content = ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: AppSpace.md),
        itemCount: 3,
        separatorBuilder: (_, _) => const Gap.md(),
        itemBuilder: (_, _) => const SkeletonCard(),
      );
    } else if (failure != null) {
      content = SingleChildScrollView(
        child: ErrorState(failure: failure, onRetry: notifier.load),
      );
    } else if (state.isEmpty) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: EmptyState(
          icon: Icons.event_note_outlined,
          title: l10n.bookingsEmptyTitle,
          body: l10n.bookingsEmptyBody,
          action: SecondaryButton(
            label: l10n.bookingsFind,
            onPressed: () => context.go(Routes.explore),
          ),
        ),
      );
    } else {
      content = NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          if (scroll.metrics.extentAfter < AppSize.touchTarget * 6 &&
              loadMoreFailure == null) {
            notifier.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          itemCount: state.items.length + 1,
          separatorBuilder: (_, _) => const Gap.md(),
          itemBuilder: (context, index) {
            if (index < state.items.length) {
              final booking = state.items[index];
              return _BookingCard(
                booking: booking,
                onTap: () => context.push(Routes.booking(booking.id)),
              );
            }
            if (state.isLoadingMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.lg),
                  child: SizedBox.square(
                    dimension: AppSize.spinner,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSize.focusBorderWidth,
                    ),
                  ),
                ),
              );
            }
            if (loadMoreFailure != null) {
              return Column(
                children: [
                  Text(
                    l10n.describe(loadMoreFailure),
                    style: context.text.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextAction(
                    label: l10n.actionTryAgain,
                    onPressed: state.hasMore
                        ? notifier.loadMore
                        : notifier.load,
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return AppScaffold(
      title: l10n.tabBookings,
      scrollable: false,
      body: RefreshIndicator(onRefresh: notifier.load, child: content),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

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
            BookingStatusChip(booking: booking),
            const Gap.sm(),
            Text(
              booking.parkingLot.name,
              style: text.h3,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap.xs(),
            Text(
              '${FacilityTime.dayAndTime(booking.startAt, booking.timezone, locale)} – '
              '${FacilityTime.time(booking.endAt, booking.timezone, locale)}',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const Gap.md(),
            Wrap(
              spacing: AppSpace.lg,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(formatMoney(booking.total), style: text.price),
                Text(
                  booking.reference,
                  style: text.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontFeatures: text.price.fontFeatures,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
