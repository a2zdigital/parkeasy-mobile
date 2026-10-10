import 'package:app/core/api/json_converters.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_booking_request.freezed.dart';
part 'create_booking_request.g.dart';

/// The body of a booking request. The total the customer saw is sent so the API can refuse if the price changed; the API never trusts it as the price.
@freezed
abstract class CreateBookingRequest with _$CreateBookingRequest {
  const factory CreateBookingRequest({
    required String parkingLotId,
    required String vehicleType,
    @UtcDateTimeConverter() required DateTime startAt,
    @UtcDateTimeConverter() required DateTime endAt,
    required PaymentMode paymentMode,
    @MoneyAmountConverter() Decimal? expectedTotalAmount,
  }) = _CreateBookingRequest;

  factory CreateBookingRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateBookingRequestFromJson(json);
}
