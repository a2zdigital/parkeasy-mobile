import 'package:app/core/money/money.dart';
import 'package:app/features/booking/data/models/availability.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/booking_window_request.dart';
import 'package:app/features/booking/data/models/create_booking_request.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> bookingJson() => {
  'id': '01M4JQYWW2WEFYAASEC49S6PW3',
  'reference': 'BK-K2M5XCN4',
  'status': 'confirmed',
  'booking_mode': 'instant',
  'payment_mode': 'on_site',
  'payment_required': false,
  'parking_lot': {'id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9', 'name': 'MG Road'},
  'vehicle_type': 'car',
  'start_at': '2026-11-02T04:30:00Z',
  'end_at': '2026-11-02T06:30:00Z',
  'timezone': 'Asia/Kolkata',
  'price_lines': [
    {
      'rate_type': 'hourly',
      'quantity': 2,
      'unit_amount': '40.00',
      'amount': '80.00',
    },
  ],
  'base_amount': '80.00',
  'total_amount': '80.00',
  'currency': 'INR',
  'approval_deadline_at': null,
  'payment_deadline_at': null,
  'confirmed_at': '2026-11-02T04:00:10Z',
  'checked_in_at': null,
  'checked_out_at': null,
  'cancelled_at': null,
  'cancellation_reason': null,
  'refund_eligible': null,
  'created_at': '2026-11-02T04:00:10Z',
};

void main() {
  group('Booking', () {
    test('parses the documented shape', () {
      final booking = Booking.fromJson(bookingJson());

      expect(booking.reference, 'BK-K2M5XCN4');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.bookingMode, BookingMode.instant);
      expect(booking.paymentMode, PaymentMode.onSite);
      expect(booking.parkingLot.name, 'MG Road');
      expect(booking.startAt, DateTime.utc(2026, 11, 2, 4, 30));
      expect(booking.startAt.isUtc, isTrue);
      expect(booking.total, Money.parse('80.00', 'INR'));
      expect(booking.priceLines.single.rateType, RateType.hourly);
      expect(booking.priceLines.single.quantity, 2);
      expect(booking.cancelledAt, isNull);
      expect(booking.refundEligible, isNull);
      expect(booking.isCheckedIn, isFalse);
    });

    test('survives a status and modes the app does not know', () {
      final booking = Booking.fromJson({
        ...bookingJson(),
        'status': 'on_hold',
        'booking_mode': 'auction',
        'payment_mode': 'wallet',
      });

      expect(booking.status, BookingStatus.unknown);
      expect(booking.bookingMode, BookingMode.unknown);
      expect(booking.paymentMode, PaymentMode.unknown);
    });

    test('ignores fields added to the API later', () {
      final booking = Booking.fromJson({
        ...bookingJson(),
        'loyalty_points': 12,
        'parking_lot': {'id': 'x', 'name': 'MG Road', 'photo_url': 'https://…'},
      });

      expect(booking.reference, 'BK-K2M5XCN4');
    });

    test('is checked in between arrival and departure', () {
      final arrived = Booking.fromJson({
        ...bookingJson(),
        'checked_in_at': '2026-11-02T04:25:00Z',
      });
      final left = Booking.fromJson({
        ...bookingJson(),
        'status': 'completed',
        'checked_in_at': '2026-11-02T04:25:00Z',
        'checked_out_at': '2026-11-02T06:10:00Z',
      });

      expect(arrived.isCheckedIn, isTrue);
      expect(left.isCheckedIn, isFalse);
    });

    test('reads a cancelled booking with its refund decision', () {
      final booking = Booking.fromJson({
        ...bookingJson(),
        'status': 'cancelled',
        'cancelled_at': '2026-11-02T04:10:00Z',
        'cancellation_reason': 'Plans changed',
        'refund_eligible': true,
      });

      expect(booking.status, BookingStatus.cancelled);
      expect(booking.refundEligible, isTrue);
      expect(booking.cancellationReason, 'Plans changed');
    });
  });

  test('Quote parses lines, terms and the total', () {
    final quote = Quote.fromJson({
      'parking_lot_id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
      'vehicle_type': 'car',
      'start_at': '2026-11-02T04:30:00Z',
      'end_at': '2026-11-03T07:30:00Z',
      'timezone': 'Asia/Kolkata',
      'booking_mode': 'owner_approval',
      'accepts_online_payment': true,
      'accepts_onsite_payment': false,
      'lines': [
        {
          'rate_type': 'daily',
          'quantity': 1,
          'unit_amount': '250.00',
          'amount': '250.00',
        },
        {
          'rate_type': 'hourly',
          'quantity': 3,
          'unit_amount': '40.00',
          'amount': '120.00',
        },
      ],
      'base_amount': '370.00',
      'total_amount': '370.00',
      'currency': 'INR',
    });

    expect(quote.bookingMode, BookingMode.ownerApproval);
    expect(quote.acceptsOnsitePayment, isFalse);
    expect(quote.lines.map((l) => l.rateType), [
      RateType.daily,
      RateType.hourly,
    ]);
    expect(quote.total.toWire(), '370.00');
  });

  test('Availability parses', () {
    final availability = Availability.fromJson({
      'parking_lot_id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
      'vehicle_type': 'car',
      'start_at': '2026-11-02T04:30:00Z',
      'end_at': '2026-11-02T06:30:00Z',
      'capacity': 40,
      'spaces_left': 0,
      'is_within_operating_hours': true,
      'is_available': false,
    });

    expect(availability.spacesLeft, 0);
    expect(availability.isAvailable, isFalse);
  });

  group('requests', () {
    final start = DateTime.utc(2026, 11, 2, 4, 30);
    final end = DateTime.utc(2026, 11, 2, 6, 30);

    test('a quote request is written in the API field names', () {
      final json = BookingWindowRequest(
        parkingLotId: 'lot',
        vehicleType: 'car',
        startAt: start,
        endAt: end,
      ).toJson();

      expect(json, {
        'parking_lot_id': 'lot',
        'vehicle_type': 'car',
        'start_at': '2026-11-02T04:30:00Z',
        'end_at': '2026-11-02T06:30:00Z',
      });
    });

    test(
      'a booking request sends money as a string and the mode as its code',
      () {
        final json = CreateBookingRequest(
          parkingLotId: 'lot',
          vehicleType: 'car',
          startAt: start,
          endAt: end,
          paymentMode: PaymentMode.onSite,
          expectedTotalAmount: Decimal.parse('80'),
        ).toJson();

        expect(json['payment_mode'], 'on_site');
        expect(json['expected_total_amount'], '80.00');
      },
    );

    test('a booking request omits the expected total when there is none', () {
      final json = CreateBookingRequest(
        parkingLotId: 'lot',
        vehicleType: 'car',
        startAt: start,
        endAt: end,
        paymentMode: PaymentMode.online,
      ).toJson();

      expect(json.containsKey('expected_total_amount'), isFalse);
    });
  });
}
