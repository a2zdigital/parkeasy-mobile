import 'package:app/core/api/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'online_earnings.freezed.dart';
part 'online_earnings.g.dart';

/// Totals for bookings paid online.
@freezed
abstract class OnlineEarnings with _$OnlineEarnings {
  const factory OnlineEarnings({
    @MoneyAmountConverter() required Decimal collected,
    @MoneyAmountConverter() required Decimal commission,
    @MoneyAmountConverter() required Decimal earned,
    @MoneyAmountConverter() required Decimal refunded,

    /// GST on parking collected for the owner (ADR-0017). Absent from older API builds.
    @MoneyAmountConverter() Decimal? parkingGst,
    @MoneyAmountConverter() Decimal? commissionTax,
    @MoneyAmountConverter() Decimal? tcs,
  }) = _OnlineEarnings;

  factory OnlineEarnings.fromJson(Map<String, dynamic> json) =>
      _$OnlineEarningsFromJson(json);
}
