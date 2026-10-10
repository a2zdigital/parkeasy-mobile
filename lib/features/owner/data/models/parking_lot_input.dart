import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_lot_input.freezed.dart';
part 'parking_lot_input.g.dart';

/// The fields an owner may set on a facility. Only the fields that are not null are sent, so the same type serves create and partial update.
@freezed
abstract class ParkingLotInput with _$ParkingLotInput {
  const factory ParkingLotInput({
    String? name,
    String? description,
    String? addressLine,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? timezone,
    BookingMode? bookingMode,
    bool? acceptsOnlinePayment,
    bool? acceptsOnsitePayment,
    List<String>? amenities,
  }) = _ParkingLotInput;

  factory ParkingLotInput.fromJson(Map<String, dynamic> json) =>
      _$ParkingLotInputFromJson(json);
}
