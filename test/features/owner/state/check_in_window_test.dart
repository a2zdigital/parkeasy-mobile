import 'package:app/features/owner/state/owner_booking_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The booking in `bookingJson()` runs 04:30 to 06:30 UTC on 2 November.
void main() {
  const path = '/owner/bookings/$bookingId';

  Future<OwnerBookingState> at(
    DateTime now, [
    Map<String, dynamic>? booking,
  ]) async {
    final h = Harness(now: now);
    final c = h.container();
    h.http.stubs[path] = {'data': booking ?? bookingJson()};
    h.http.stubs['$path/collection'] = collectionJson();
    c.listen(ownerBookingProvider(bookingId), (_, _) {});
    await h.http.idle();
    final value = c.read(ownerBookingProvider(bookingId)).value!;
    c.dispose();
    return value;
  }

  test('hidden more than 30 minutes before the start', () async {
    expect((await at(DateTime.utc(2026, 11, 2, 3, 59))).canCheckIn, isFalse);
  });

  test('shown from 30 minutes before the start until the end', () async {
    expect((await at(DateTime.utc(2026, 11, 2, 4))).canCheckIn, isTrue);
    expect((await at(DateTime.utc(2026, 11, 2, 5, 15))).canCheckIn, isTrue);
    expect((await at(DateTime.utc(2026, 11, 2, 6, 29))).canCheckIn, isTrue);
  });

  test('hidden once the booking has ended', () async {
    expect((await at(DateTime.utc(2026, 11, 2, 6, 30))).canCheckIn, isFalse);
    expect((await at(DateTime.utc(2026, 11, 3, 9))).canCheckIn, isFalse);
  });

  test('hidden after a successful check-in', () async {
    final parked = await at(
      DateTime.utc(2026, 11, 2, 4, 40),
      bookingJson(checkedInAt: '2026-11-02T04:35:00Z'),
    );
    expect(parked.canCheckIn, isFalse);
    expect(parked.canCheckOut, isTrue);
  });

  test('hidden for bookings that are not confirmed', () async {
    for (final status in [
      'pending_approval',
      'cancelled',
      'expired',
      'completed',
      'no_show',
    ]) {
      final state = await at(
        DateTime.utc(2026, 11, 2, 5),
        bookingJson(status: status),
      );
      expect(state.canCheckIn, isFalse, reason: status);
    }
  });
}
