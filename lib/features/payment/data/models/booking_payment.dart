import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/payment/data/models/payment_order.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_payment.freezed.dart';
part 'booking_payment.g.dart';

/// The payment position of a booking: what the app polls after checkout.
@freezed
abstract class BookingPayment with _$BookingPayment {
  const factory BookingPayment({
    @JsonKey(unknownEnumValue: PaymentMode.unknown)
    required PaymentMode paymentMode,
    @JsonKey(unknownEnumValue: BookingStatus.unknown)
    required BookingStatus bookingStatus,
    @Default(false) bool paymentRequired,
    PaymentOrder? order,
  }) = _BookingPayment;

  factory BookingPayment.fromJson(Map<String, dynamic> json) =>
      _$BookingPaymentFromJson(json);
}
