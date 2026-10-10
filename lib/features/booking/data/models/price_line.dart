import 'package:app/core/api/json_converters.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_line.freezed.dart';
part 'price_line.g.dart';

/// One line of a price: a number of hours or days at a rate.
@freezed
abstract class PriceLine with _$PriceLine {
  const factory PriceLine({
    @JsonKey(unknownEnumValue: RateType.unknown) required RateType rateType,
    required int quantity,
    @MoneyAmountConverter() required Decimal unitAmount,
    @MoneyAmountConverter() required Decimal amount,
  }) = _PriceLine;

  factory PriceLine.fromJson(Map<String, dynamic> json) =>
      _$PriceLineFromJson(json);
}
