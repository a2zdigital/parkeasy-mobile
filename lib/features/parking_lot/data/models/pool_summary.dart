import 'package:app/core/api/json_converters.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pool_summary.freezed.dart';
part 'pool_summary.g.dart';

/// The rates for one vehicle type, as shown in search results. A rate is null when the facility does not offer it.
@freezed
abstract class PoolSummary with _$PoolSummary {
  const factory PoolSummary({
    required CodeName vehicleType,
    @MoneyAmountConverter() Decimal? hourlyRate,
    @MoneyAmountConverter() Decimal? dailyRate,
  }) = _PoolSummary;

  factory PoolSummary.fromJson(Map<String, dynamic> json) =>
      _$PoolSummaryFromJson(json);
}
