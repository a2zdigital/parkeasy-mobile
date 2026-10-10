import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pool_rate.freezed.dart';
part 'pool_rate.g.dart';

/// The price of one unit of time for a pool.
@freezed
abstract class PoolRate with _$PoolRate {
  const PoolRate._();

  const factory PoolRate({
    @JsonKey(unknownEnumValue: RateType.unknown) required RateType rateType,
    @MoneyAmountConverter() required Decimal amount,
    required String currency,
  }) = _PoolRate;

  factory PoolRate.fromJson(Map<String, dynamic> json) =>
      _$PoolRateFromJson(json);

  Money get price => Money(amount, currency);
}
