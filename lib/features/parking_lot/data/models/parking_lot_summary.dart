import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/pool_summary.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_lot_summary.freezed.dart';
part 'parking_lot_summary.g.dart';

/// A facility as it appears in search results, with its distance from the searched point.
@freezed
abstract class ParkingLotSummary with _$ParkingLotSummary {
  const ParkingLotSummary._();

  const factory ParkingLotSummary({
    required String id,
    required String name,
    required String addressLine,
    required String city,
    @FlexibleDoubleConverter() required double latitude,
    @FlexibleDoubleConverter() required double longitude,
    @FlexibleDoubleConverter() required double distanceKm,
    @JsonKey(unknownEnumValue: BookingMode.unknown)
    required BookingMode bookingMode,
    @Default(false) bool acceptsOnlinePayment,
    @Default(false) bool acceptsOnsitePayment,
    @Default(<String>[]) List<String> amenities,
    @Default(<PoolSummary>[]) List<PoolSummary> pools,
    @MoneyAmountConverter() Decimal? fromHourlyRate,
    required String currency,
  }) = _ParkingLotSummary;

  factory ParkingLotSummary.fromJson(Map<String, dynamic> json) =>
      _$ParkingLotSummaryFromJson(json);

  /// The lowest hourly rate at the facility, when it has one.
  Money? get fromPrice =>
      fromHourlyRate == null ? null : Money(fromHourlyRate!, currency);
}
