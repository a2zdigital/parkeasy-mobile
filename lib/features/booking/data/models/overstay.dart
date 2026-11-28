import 'package:app/core/api/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'overstay.freezed.dart';
part 'overstay.g.dart';

/// Time past the booked end, as the API priced it: owed so far while
/// parked, or as charged at check-out.
@freezed
abstract class Overstay with _$Overstay {
  const factory Overstay({
    required int minutes,
    @MoneyAmountConverter() required Decimal parkingAmount,
    @MoneyAmountConverter() required Decimal gstAmount,
    @MoneyAmountConverter() required Decimal totalAmount,
  }) = _Overstay;

  factory Overstay.fromJson(Map<String, dynamic> json) =>
      _$OverstayFromJson(json);
}
