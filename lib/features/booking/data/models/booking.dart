import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/booking/data/models/booking_lot_ref.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/charge_line.dart';
import 'package:app/features/booking/data/models/overstay.dart';
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

    /// The numbered bay given to this booking; null where any space will do.
    String? spaceLabel,

    /// The gate code (also the QR code's text). Only the customer gets it,
    /// while the booking is confirmed and not yet checked in.
    String? checkInCode,

    /// The separate code for leaving, while parked. Only the customer sees it.
    String? checkOutCode,

    /// Time past the booked end and its price; null when there is none.
    Overstay? overstay,

    /// Whether the booking's own charge is paid: paid_online, unpaid,
    /// collected_at_facility or due_at_facility. Null from older API builds.
    String? bookingPaymentStatus,
    @UtcDateTimeConverter() required DateTime startAt,
    @UtcDateTimeConverter() required DateTime endAt,
    required String timezone,
    @Default(<PriceLine>[]) List<PriceLine> priceLines,

    /// What the customer was charged: parking, then any GST on it.
    @Default(<ChargeLine>[]) List<ChargeLine> charges,
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

    /// The score the customer gave, once rated. Null from older API builds too.
    int? myRating,

    /// A paid booking cancelled by this time is refunded in full.
    @UtcDateTimeConverter() DateTime? freeCancellationUntil,

    /// What cancelling now would do, decided by the server. Null from older
    /// API builds.
    bool? refundIfCancelledNow,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);

  Money get total => Money(totalAmount, currency);

  /// The booking's amount is still to be collected at the facility; the
  /// person at the gate records it with the check-out.
  bool get paymentDueAtFacility => bookingPaymentStatus == 'due_at_facility';

  /// An online booking whose payment has not gone through: it cannot be
  /// checked out until the customer pays.
  bool get onlinePaymentMissing => bookingPaymentStatus == 'unpaid';

  /// The customer has arrived and has not left yet: parked, or confirmed and
  /// checked in on an API from before the parked status.
  bool get isCheckedIn =>
      status == BookingStatus.parked ||
      (status == BookingStatus.confirmed &&
          checkedInAt != null &&
          checkedOutAt == null);
}
