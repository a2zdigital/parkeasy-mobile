import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_lot_options.freezed.dart';
part 'parking_lot_options.g.dart';

/// The choices offered when creating or editing a facility.
@freezed
abstract class ParkingLotOptions with _$ParkingLotOptions {
  const factory ParkingLotOptions({
    @JsonKey(unknownEnumValue: BookingMode.unknown)
    required BookingMode defaultBookingMode,
    @JsonKey(unknownEnumValue: BookingMode.unknown)
    @Default(<BookingMode>[])
    List<BookingMode> selectableBookingModes,
    @JsonKey(unknownEnumValue: RateType.unknown)
    @Default(<RateType>[])
    List<RateType> rateTypes,
    @Default(<CodeName>[]) List<CodeName> vehicleTypes,
    @Default(<CodeName>[]) List<CodeName> amenities,
    required String defaultTimezone,
    required String currency,
  }) = _ParkingLotOptions;

  factory ParkingLotOptions.fromJson(Map<String, dynamic> json) =>
      _$ParkingLotOptionsFromJson(json);
}
