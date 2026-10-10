import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/booking/data/models/booking_lot_ref.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/data/models/price_line.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

/// A booking as the API reports it. The owner sees the same shape; it never carries the customer's identity.
@freezed
abstract class Booking with _$Booking {
  const Booking._();

  const factory Booking({
    required String id,
    required String reference,
    @JsonKey(unknownEnumValue: BookingStatus.unknown)
    required BookingStatus status,
    @JsonKey(unknownEnumValue: BookingMode.unknown)
    required BookingMode bookingMode,
    @JsonKey(unknownEnumValue: PaymentMode.unknown)
    required PaymentMode paymentMode,
    @Default(false) bool paymentRequired,
    required BookingLotRef parkingLot,
    required String vehicleType,
    @UtcDateTimeConverter() required DateTime startAt,
    @UtcDateTimeConverter() required DateTime endAt,
    required String timezone,
    @Default(<PriceLine>[]) List<PriceLine> priceLines,
    @MoneyAmountConverter() required Decimal baseAmount,
    @MoneyAmountConverter() required Decimal totalAmount,
    required String currency,
    @UtcDateTimeConverter() DateTime? approvalDeadlineAt,
    @UtcDateTimeConverter() DateTime? paymentDeadlineAt,
    @UtcDateTimeConverter() DateTime? confirmedAt,
    @UtcDateTimeConverter() DateTime? checkedInAt,
    @UtcDateTimeConverter() DateTime? checkedOutAt,
    @UtcDateTimeConverter() DateTime? cancelledAt,
    String? cancellationReason,
    bool? refundEligible,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);

  Money get total => Money(totalAmount, currency);

  /// Confirmed and the customer has arrived, but has not left yet.
  bool get isCheckedIn =>
      status == BookingStatus.confirmed &&
      checkedInAt != null &&
      checkedOutAt == null;
}
