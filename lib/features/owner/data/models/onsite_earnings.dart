import 'package:app/core/api/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onsite_earnings.freezed.dart';
part 'onsite_earnings.g.dart';

/// Totals for bookings paid at the facility.
@freezed
abstract class OnsiteEarnings with _$OnsiteEarnings {
  const factory OnsiteEarnings({
    @MoneyAmountConverter() required Decimal collected,
    @MoneyAmountConverter() required Decimal commission,
  }) = _OnsiteEarnings;

  factory OnsiteEarnings.fromJson(Map<String, dynamic> json) =>
      _$OnsiteEarningsFromJson(json);
}
