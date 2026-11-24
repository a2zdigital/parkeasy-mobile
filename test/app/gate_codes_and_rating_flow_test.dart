import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Confirmed → Parked → Completed on the customer's phone: the check-out
/// code while parked, and the rating sheet as soon as check-out is seen.
void main() {
  Future<void> openBooking(
    WidgetTester tester,
    Harness h, {
    String tab = 'Ongoing',
  }) async {
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BK-K2M5XCN4'));
    await tester.pumpAndSettle();
  }

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  Map<String, dynamic> body(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);

  Map<String, dynamic> parked() => bookingJson(
    status: 'parked',
    checkedInAt: '2026-11-02T04:35:00Z',
    checkOutCode: 'Q7M3K9TP',
  );

  Map<String, dynamic> completed({int? myRating}) => bookingJson(
    status: 'completed',
    checkedInAt: '2026-11-02T04:35:00Z',
    checkedOutAt: '2026-11-02T06:10:00Z',
    myRating: myRating,
  );

  testWidgets(
    'a parked booking shows its check-out code, not the check-in one',
    (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/bookings'] = bookingsJson([parked()]);
      h.http.stubs['/bookings/$bookingId'] = {'data': parked()};
      await openBooking(tester, h);

      expect(find.text('Parked'), findsWidgets);
      expect(find.text('Checkout QR Code'), findsOneWidget);
      expect(find.text('Q7M3 K9TP'), findsOneWidget);
      expect(find.text('Check-in code'), findsNothing);
      expect(
        find.text('Show this code to the parking attendant when leaving.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Show your check-out code when you leave'),
        findsOneWidget,
      );
    },
  );

  testWidgets('checking out at the gate asks for a rating straight away', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs['/bookings'] = bookingsJson([parked()]);
    h.http.stubs['/bookings/$bookingId'] = {'data': parked()};
    await openBooking(tester, h);
    expect(find.text('How was your parking experience?'), findsNothing);

    // The attendant scans the check-out code; the page re-reads the booking.
    h.http.stubs['/bookings/$bookingId'] = {'data': completed()};
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('How was your parking experience?'), findsOneWidget);
    expect(find.text('Share your experience with us.'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    // Checked out: the check-out code is gone.
    expect(find.text('Checkout QR Code'), findsNothing);

    // Submit needs a star first.
    final submit = find.widgetWithText(FilledButton, 'Submit');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('rating-star-4')));
    await tester.enterText(
      find.byKey(const ValueKey('rating-feedback')),
      'Easy to find, friendly attendant',
    );
    h.http.respond(201, {
      'data': {'score': 4},
    });
    h.http.stubs['/bookings/$bookingId'] = {'data': completed(myRating: 4)};
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    final rating = writes(
      h,
    ).singleWhere((r) => r.path == '/bookings/$bookingId/rating');
    expect(body(rating), {
      'score': 4,
      'comment': 'Easy to find, friendly attendant',
    });
    expect(find.text('How was your parking experience?'), findsNothing);
    expect(find.text('Thank you for your rating!'), findsOneWidget);
    // The rating shows on the completed booking.
    expect(find.text('Your rating'), findsOneWidget);
  });

  testWidgets('"Maybe later" closes the sheet and sends nothing', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs['/bookings'] = bookingsJson([parked()]);
    h.http.stubs['/bookings/$bookingId'] = {'data': parked()};
    await openBooking(tester, h);

    h.http.stubs['/bookings/$bookingId'] = {'data': completed()};
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();

    expect(find.text('How was your parking experience?'), findsNothing);
    expect(writes(h), isEmpty);
  });

  testWidgets('a completed booking opened later does not pop the sheet', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs['/bookings'] = bookingsJson([completed()]);
    h.http.stubs['/bookings/$bookingId'] = {'data': completed()};
    await openBooking(tester, h, tab: 'Past');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('How was your parking experience?'), findsNothing);
  });
}
