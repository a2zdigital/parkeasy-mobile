import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/time/facility_time.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/inventory_pool.dart';
import 'package:app/features/parking_lot/data/models/operating_hour.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:app/features/parking_lot/state/parking_lot_provider.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ParkingLotScreen extends ConsumerWidget {
  const ParkingLotScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lot = ref.watch(parkingLotProvider(id));

    return lot.when(
      loading: () => const AppScaffold(
        title: '',
        body: Column(
          children: [Gap.lg(), SkeletonCard(), Gap.md(), SkeletonCard()],
        ),
      ),
      error: (error, _) => AppScaffold(
        title: '',
        body: Center(
          child: ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(parkingLotProvider(id)),
          ),
        ),
      ),
      data: (lot) => AppScaffold(
        title: '',
        body: _Details(lot: lot),
        bottom: lot.pools.isEmpty
            ? null
            : PrimaryButton(
                label: l10n.lotChooseTime,
                onPressed: () => context.push(Routes.chooseTime(lot.id)),
              ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.lot});

  final ParkingLot lot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final text = context.text;
    final description = lot.description;

    final String payment;
    if (lot.acceptsOnlinePayment && lot.acceptsOnsitePayment) {
      payment = l10n.lotPayBoth;
    } else {
      payment = lot.acceptsOnsitePayment
          ? l10n.lotPayOnsite
          : l10n.lotPayOnline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap.sm(),
        Text(lot.name, style: text.h1),
        const Gap.sm(),
        Text(
          '${lot.addressLine}, ${lot.city} ${lot.postalCode}',
          style: text.body.copyWith(color: colors.textSecondary),
        ),
        if (description != null && description.isNotEmpty) ...[
          const Gap.md(),
          Text(description, style: text.body),
        ],
        const Gap.lg(),
        AppBanner(
          tone: lot.bookingMode == BookingMode.ownerApproval
              ? StatusTone.warning
              : StatusTone.info,
          message: lot.bookingMode == BookingMode.ownerApproval
              ? l10n.lotApprovalNote
              : l10n.lotInstantNote,
        ),
        const Gap.md(),
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.payments_outlined,
                size: AppSize.iconSmall,
                color: colors.textSecondary,
              ),
            ),
            const Gap.sm(),
            Expanded(child: Text(payment, style: text.bodySmall)),
          ],
        ),
        SectionHeader(l10n.lotRates),
        if (lot.pools.isEmpty)
          Text(
            l10n.lotNoSpaces,
            style: text.body.copyWith(color: colors.textSecondary),
          )
        else
          for (final (index, pool) in lot.pools.indexed) ...[
            if (index > 0) const Gap.md(),
            _PoolCard(pool: pool),
          ],
        if (lot.operatingHours.isNotEmpty) ...[
          SectionHeader(l10n.lotHours),
          _HoursCard(hours: lot.operatingHours),
        ],
        if (lot.amenities.isNotEmpty) ...[
          SectionHeader(l10n.lotAmenities),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final amenity in lot.amenities)
                StatusChip(tone: StatusTone.neutral, label: amenity.name),
            ],
          ),
        ],
        const Gap.xl(),
      ],
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool});

  final InventoryPool pool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(pool.vehicleType.name, style: text.h3)),
              Text(
                l10n.lotSpaces(pool.capacity),
                style: text.bodySmall.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          for (final rate in pool.rates) ...[
            const Gap.sm(),
            Text(switch (rate.rateType) {
              RateType.hourly => l10n.pricePerHour(formatMoney(rate.price)),
              RateType.daily => l10n.pricePerDay(formatMoney(rate.price)),
              RateType.unknown => formatMoney(rate.price),
            }, style: text.price),
          ],
        ],
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.hours});

  final List<OperatingHour> hours;

  static String _describe(
    AppLocalizations l10n,
    OperatingHour day,
    String locale,
  ) {
    final opens = day.opensAt;
    final closes = day.closesAt;
    if (day.isClosed || opens == null || closes == null) return l10n.lotClosed;
    if (opens.startsWith('00:00') && closes.startsWith('24:00')) {
      return l10n.lotOpen24;
    }
    return l10n.lotHoursRange(
      FacilityTime.clock(opens, locale),
      FacilityTime.clock(closes, locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sorted = [...hours]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return AppCard(
      child: Column(
        children: [
          for (final (index, day) in sorted.indexed) ...[
            if (index > 0) const Gap.sm(),
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      FacilityTime.weekday(day.dayOfWeek, locale),
                      style: text.bodySmall,
                    ),
                  ),
                  Text(
                    _describe(l10n, day, locale),
                    style: text.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
