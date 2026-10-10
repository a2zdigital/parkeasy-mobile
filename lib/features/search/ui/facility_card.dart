import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One search result: name, how far, where, and the starting price.
class FacilityCard extends StatelessWidget {
  const FacilityCard({required this.lot, required this.onTap, super.key});

  final ParkingLotSummary lot;
  final VoidCallback onTap;

  static String distance(AppLocalizations l10n, double km) => km < 1
      ? l10n.distanceMetres((km * 1000).round())
      : l10n.distanceKm(km.toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final text = context.text;
    final price = lot.fromPrice;

    return Semantics(
      button: true,
      child: AppCard(
        onTap: onTap,
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
            Text(
              '${distance(l10n, lot.distanceKm)} · ${lot.addressLine}',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
