import 'package:app/core/api/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_window_request.freezed.dart';
part 'booking_window_request.g.dart';

/// The body of a quote request: a facility, a vehicle type and a window.
@freezed
abstract class BookingWindowRequest with _$BookingWindowRequest {
  const factory BookingWindowRequest({
    required String parkingLotId,
    required String vehicleType,
    @UtcDateTimeConverter() required DateTime startAt,
    @UtcDateTimeConverter() required DateTime endAt,
  }) = _BookingWindowRequest;

  factory BookingWindowRequest.fromJson(Map<String, dynamic> json) =>
      _$BookingWindowRequestFromJson(json);
}
