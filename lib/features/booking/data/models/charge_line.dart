import 'package:app/core/api/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'charge_line.freezed.dart';
part 'charge_line.g.dart';

/// One line of what the customer pays: the parking charge, or a GST line on
/// it. The lines add up to the total; the app never calculates them.
@freezed
abstract class ChargeLine with _$ChargeLine {
  const ChargeLine._();

  const factory ChargeLine({
    /// parking, parking_cgst, parking_sgst or parking_igst.
    required String code,

    /// Percentage for a tax line; null for the parking charge.
    String? rate,
    @MoneyAmountConverter() required Decimal amount,
  }) = _ChargeLine;

  factory ChargeLine.fromJson(Map<String, dynamic> json) =>
      _$ChargeLineFromJson(json);

  bool get isTax => code != 'parking';

  /// CGST, SGST or IGST for a tax line.
  String get taxName => switch (code) {
    'parking_cgst' => 'CGST',
    'parking_sgst' => 'SGST',
    'parking_igst' => 'IGST',
    _ => code.toUpperCase(),
  };
}
