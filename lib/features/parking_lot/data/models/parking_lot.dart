import 'package:app/core/api/json_converters.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/parking_lot/data/models/inventory_pool.dart';
import 'package:app/features/parking_lot/data/models/operating_hour.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_lot.freezed.dart';
part 'parking_lot.g.dart';

/// A facility with everything a customer needs to decide: address, hours, spaces and rates.
@freezed
abstract class ParkingLot with _$ParkingLot {
  const factory ParkingLot({
    required String id,
    required String name,
    String? description,
    required String addressLine,
    required String city,
    required String state,
    required String postalCode,
    @FlexibleDoubleConverter() required double latitude,
    @FlexibleDoubleConverter() required double longitude,
    required String timezone,
    @JsonKey(unknownEnumValue: BookingMode.unknown)
    required BookingMode bookingMode,
    @Default(false) bool acceptsOnlinePayment,
    @Default(false) bool acceptsOnsitePayment,
    @Default(<CodeName>[]) List<CodeName> amenities,
    @Default(<OperatingHour>[]) List<OperatingHour> operatingHours,
    @Default(<InventoryPool>[]) List<InventoryPool> pools,
  }) = _ParkingLot;

  factory ParkingLot.fromJson(Map<String, dynamic> json) =>
      _$ParkingLotFromJson(json);
}
