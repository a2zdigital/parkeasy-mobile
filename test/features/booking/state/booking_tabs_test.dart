import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// Which tab a booking belongs to, from its status and its UTC times.
/// The booking runs 04:30–06:30 UTC (10:00–12:00 in Kolkata).
void main() {
  Booking booking(String status, {String? checkedInAt}) =>
      Booking.fromJson(bookingJson(status: status, checkedInAt: checkedInAt));

  final start = DateTime.utc(2026, 11, 2, 4, 30);
  final end = DateTime.utc(2026, 11, 2, 6, 30);
  const second = Duration(seconds: 1);

  group('confirmed', () {
    test('is Upcoming until the second it starts', () {
      expect(
        classifyBooking(booking('confirmed'), start.subtract(second)),
        CustomerBookingTab.upcoming,
      );
    });

    test('is Ongoing from its start until the second before its end', () {
      expect(
        classifyBooking(booking('confirmed'), start),
        CustomerBookingTab.ongoing,
      );
      expect(
        classifyBooking(booking('confirmed'), end.subtract(second)),
        CustomerBookingTab.ongoing,
      );
    });

    test(
      'is Past once its end time has passed, never left Upcoming or Ongoing',
      () {
        expect(
          classifyBooking(booking('confirmed'), end),
          CustomerBookingTab.past,
        );
        expect(
          classifyBooking(
            booking('confirmed'),
            end.add(const Duration(days: 3)),
          ),
          CustomerBookingTab.past,
        );
      },
    );
  });

  test('a parked booking is Ongoing until it is checked out at the gate', () {
    final parked = booking('parked', checkedInAt: '2026-11-02T04:35:00Z');
    expect(classifyBooking(parked, start), CustomerBookingTab.ongoing);
    // Past its end time it still needs checking out, so it stays Ongoing.
    expect(
      classifyBooking(parked, end.add(const Duration(minutes: 30))),
      CustomerBookingTab.ongoing,
    );
  });

  test(
    'a request or an unpaid booking is Upcoming until its end, then Past',
    () {
      for (final status in ['pending_approval', 'awaiting_payment']) {
        expect(
          classifyBooking(booking(status), start.subtract(second)),
          CustomerBookingTab.upcoming,
          reason: status,
        );
        expect(
          classifyBooking(booking(status), end),
          CustomerBookingTab.past,
          reason: status,
        );
      }
    },
  );

  test('finished bookings are Past whenever they are looked at', () {
    for (final status in [
      'completed',
      'cancelled',
      'expired',
      'no_show',
      'rejected',
    ]) {
      for (final now in [
        start.subtract(const Duration(hours: 1)),
        start,
        end,
      ]) {
        expect(
          classifyBooking(booking(status), now),
          CustomerBookingTab.past,
          reason: '$status at $now',
        );
      }
    }
  });
}
