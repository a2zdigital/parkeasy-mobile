import 'package:app/core/money/money.dart';
import 'package:app/core/money/money_format.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/features/booking/data/models/price_line.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// How a price is made up, exactly as the API returned it: one row per
/// line, then the total. Nothing here is calculated by the app.
class PriceBreakdown extends StatelessWidget {
  const PriceBreakdown({required this.lines, required this.total, super.key});

  final List<PriceLine> lines;
  final Money total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;

    String describe(PriceLine line) {
      final unit = formatMoney(Money(line.unitAmount, total.currency));
      return switch (line.rateType) {
        RateType.hourly => l10n.timeLineHours(line.quantity, unit),
        RateType.daily => l10n.timeLineDays(line.quantity, unit),
        RateType.unknown => l10n.timeLineOther(line.quantity, unit),
      };
    }

    return AppCard(
      child: Column(
        children: [
          for (final line in lines) ...[
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      describe(line),
                      style: text.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const Gap.md(),
                  Text(
                    formatMoney(Money(line.amount, total.currency)),
                    style: text.bodySmall.copyWith(
                      fontFeatures: text.price.fontFeatures,
                    ),
                  ),
                ],
              ),
            ),
            const Gap.sm(),
          ],
          const Divider(),
          const Gap.sm(),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(child: Text(l10n.timeTotal, style: text.h3)),
                Text(formatMoney(total), style: text.price),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
