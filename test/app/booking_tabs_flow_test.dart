import 'package:app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Upcoming, Ongoing and Past on the Bookings tab. "Now" is 10:00 in
/// Kolkata (04:30 UTC). The API answers every status filter with the same
/// list here, so a booking showing in the wrong tab, or in two, would show.
void main() {
  final now = DateTime.utc(2026, 11, 2, 4, 30);

  final bookings = [
    // Starts later today: Upcoming.
    bookingJson(
      id: 'upcoming',
      reference: 'BK-UPCOMING',
      startAt: '2026-11-02T08:30:00Z',
      endAt: '2026-11-02T10:30:00Z',
    ),
    // Started at 04:30 exactly, not yet checked in: Ongoing.
    bookingJson(id: 'started', reference: 'BK-STARTED'),
    // Parked: Ongoing, with its check-in time and check-out-by time.
    bookingJson(
      id: 'parked',
      reference: 'BK-PARKED',
      status: 'parked',
      startAt: '2026-11-02T03:30:00Z',
      endAt: '2026-11-02T05:30:00Z',
      checkedInAt: '2026-11-02T03:35:00Z',
      checkOutCode: 'Q7M3K9TP',
    ),
    // Over at 04:30 exactly, never closed by the API yet: Past.
    bookingJson(
      id: 'over',
      reference: 'BK-OVER',
      startAt: '2026-11-02T02:30:00Z',
      endAt: '2026-11-02T04:30:00Z',
    ),
    bookingJson(id: 'done', reference: 'BK-DONE', status: 'completed'),
    bookingJson(id: 'gone', reference: 'BK-GONE', status: 'cancelled'),
    bookingJson(id: 'missed', reference: 'BK-MISSED', status: 'no_show'),
  ];

  Future<void> openBookings(WidgetTester tester, Harness h) async {
    h.http.stubs['/bookings'] = bookingsJson(bookings);
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
  }

  Future<void> showTab(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab).first);
    await tester.pumpAndSettle();
  }

  void expectOnly(List<String> shown) {
    for (final b in bookings) {
      final reference = b['reference']! as String;
      expect(
        find.text(reference),
        shown.contains(reference) ? findsOneWidget : findsNothing,
        reason: reference,
      );
    }
  }

  testWidgets('each booking shows in exactly one of the three tabs', (
    tester,
  ) async {
    // Tall enough that every card in a tab is built.
    tester.view.physicalSize = const Size(1170, 5000);
    addTearDown(tester.view.resetPhysicalSize);
    final h = Harness(token: validToken(), now: now);
    await openBookings(tester, h);

    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expectOnly(['BK-UPCOMING']);

    await showTab(tester, 'Ongoing');
    expectOnly(['BK-STARTED', 'BK-PARKED']);
    // The parked booking says when they arrived and when to leave by.
    expect(
      find.text('Checked in 9:05 AM · Check out by 11:00 AM'),
      findsOneWidget,
    );

    await showTab(tester, 'Past');
    expectOnly(['BK-OVER', 'BK-DONE', 'BK-GONE', 'BK-MISSED']);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
  });

  testWidgets('switching tabs reads the bookings again', (tester) async {
    final h = Harness(token: validToken(), now: now);
    await openBookings(tester, h);
    final before = h.http.requests.where((r) => r.path == '/bookings').length;

    await showTab(tester, 'Ongoing');

    final statuses = h.http.requests
        .where((r) => r.path == '/bookings')
        .skip(before)
        .map((r) => r.uri.queryParameters['filter[status]'])
        .toList();
    expect(statuses, ['confirmed', 'parked']);
  });

  testWidgets('a parked booking opens with its check-out code from Ongoing', (
    tester,
  ) async {
    final h = Harness(token: validToken(), now: now);
    h.http.stubs['/bookings/parked'] = {'data': bookings[2]};
    await openBookings(tester, h);
    await showTab(tester, 'Ongoing');

    await tester.tap(find.text('BK-PARKED'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout QR Code'), findsOneWidget);
    expect(find.text('Q7M3 K9TP'), findsOneWidget);
  });

  testWidgets('coming back to the Bookings tab reads the bookings again', (
    tester,
  ) async {
    final h = Harness(token: validToken(), now: now);
    await openBookings(tester, h);
    final before = h.http.requests.where((r) => r.path == '/bookings').length;

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(
      h.http.requests.where((r) => r.path == '/bookings').length,
      greaterThan(before),
    );
  });

  testWidgets(
    'checked in at the gate: the booking moves to Ongoing by itself',
    (tester) async {
      final h = Harness(token: validToken(), now: DateTime.utc(2026, 11, 2, 4));
      final upcoming = bookingJson(checkInCode: '7KQ3MZ8D');
      h.http.stubs['/bookings'] = bookingsJson([upcoming]);
      h.http.respond(200, {'data': userJson()});
      await tester.pumpWidget(
        ProviderScope(overrides: h.overrides, child: const App()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      expect(find.text('BK-K2M5XCN4'), findsOneWidget);

      // The attendant checks the car in (early, at 09:35 in Kolkata).
      h.http.stubs['/bookings'] = bookingsJson([
        bookingJson(
          status: 'parked',
          checkedInAt: '2026-11-02T04:05:00Z',
          checkOutCode: 'Q7M3K9TP',
        ),
      ]);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(
        find.text('BK-K2M5XCN4'),
        findsNothing,
        reason: 'No longer Upcoming',
      );

      await tester.tap(find.text('Ongoing'));
      await tester.pumpAndSettle();
      expect(find.text('BK-K2M5XCN4'), findsOneWidget);
      expect(find.text('Parked'), findsOneWidget);
    },
  );
}
