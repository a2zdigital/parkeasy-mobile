import 'package:app/core/api/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'availability.freezed.dart';
part 'availability.g.dart';

/// Whether a vehicle type has a free space for a window. An estimate: only creating the booking reserves a space.
@freezed
abstract class Availability with _$Availability {
  const factory Availability({
    required String parkingLotId,
    required String vehicleType,
    @UtcDateTimeConverter() required DateTime startAt,
    @UtcDateTimeConverter() required DateTime endAt,
    required int capacity,
    required int spacesLeft,
    required bool isWithinOperatingHours,
    required bool isAvailable,
  }) = _Availability;

  factory Availability.fromJson(Map<String, dynamic> json) =>
      _$AvailabilityFromJson(json);
}
