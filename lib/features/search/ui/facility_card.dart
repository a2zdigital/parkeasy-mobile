import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/screen_intro.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One search result: name, how far, where, and the starting price.
class FacilityCard extends StatelessWidget {
  const FacilityCard({
    required this.lot,
    required this.onTap,
    this.vehicleType,
    super.key,
  });

  final ParkingLotSummary lot;
  final VoidCallback onTap;

  /// The vehicle type the search is filtered by, if any: its free spaces
  /// are shown; otherwise each type's.
  final String? vehicleType;

  static String distance(AppLocalizations l10n, double km) => km < 1
      ? l10n.distanceMetres((km * 1000).round())
      : l10n.distanceKm(km.toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final text = context.text;
    final price = lot.fromPrice;
    // Free spaces, only when the search had arrival and departure times.
    final counted = [
      for (final pool in lot.pools)
        if (pool.spacesLeft != null &&
            (vehicleType == null || pool.vehicleType.code == vehicleType))
          pool,
    ];

    return Semantics(
      button: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconTile(icon: Icons.local_parking),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lot.name,
                        style: text.h3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap.xs(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.near_me_outlined,
                              size: 14,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: distance(l10n, lot.distanceKm),
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' · ${lot.addressLine}'),
                                ],
                              ),
                              style: text.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (lot.amenityDetails.isNotEmpty) ...[
                        const Gap.xs(),
                        Text(
                          lot.amenityDetails
                              .map((amenity) => amenity.name)
                              .join(' · '),
                          style: text.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap.sm(),
                Icon(Icons.chevron_right, color: colors.textSecondary),
              ],
            ),
            const Gap.md(),
            Divider(height: 1, color: colors.border),
            const Gap.md(),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  price == null
                      ? l10n.priceDailyOnly
                      : l10n.priceFromPerHour(
                          formatMoney(price, compact: true),
                        ),
                  style: text.price,
                ),
                if (counted.length == 1)
                  StatusChip(
                    tone: StatusTone.available,
                    icon: Icons.local_parking,
                    label: l10n.exploreSpacesFree(counted.single.spacesLeft!),
                  )
                else
                  for (final pool in counted)
                    StatusChip(
                      tone: (pool.spacesLeft ?? 0) > 0
                          ? StatusTone.available
                          : StatusTone.neutral,
                      icon: Icons.local_parking,
                      label: l10n.exploreSpacesFreeFor(
                        pool.spacesLeft!,
                        pool.vehicleType.name,
                      ),
                    ),
                if (lot.bookingMode == BookingMode.ownerApproval)
                  StatusChip(
                    tone: StatusTone.warning,
                    icon: Icons.schedule_outlined,
                    label: l10n.chipNeedsApproval,
                  ),
                if (lot.acceptsOnsitePayment)
                  StatusChip(
                    tone: StatusTone.neutral,
                    icon: Icons.payments_outlined,
                    label: l10n.chipPayAtFacility,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
