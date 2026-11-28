import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Find → choose time → review → book → booking → cancel → list, through
/// the real router and screens.
void main() {
  const lotPath = '/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9';

  Future<Harness> atReview(
    WidgetTester tester, {
    Map<String, dynamic>? lot,
    Map<String, dynamic>? quote,
  }) async {
    final h = Harness(
      token: validToken(),
      now: DateTime.utc(2026, 11, 2, 4, 17),
    );
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    h.http.stubs[lotPath] = lot ?? lotJson();
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();
    h.http
      ..respond(200, quote ?? quoteJson())
      ..respond(200, availabilityJson());
    await tester.tap(find.widgetWithText(PrimaryButton, 'Choose time'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    return h;
  }

  Map<String, dynamic> instantOnsiteQuote() {
    final quote = quoteJson();
    (quote['data'] as Map<String, dynamic>)
      ..['booking_mode'] = 'instant'
      ..['accepts_onsite_payment'] = true;
    return quote;
  }

  testWidgets('books a space to pay at the facility, then cancels it', (
    tester,
  ) async {
    final h = await atReview(tester, quote: instantOnsiteQuote());

    // Everything being committed to is on the screen before the action.
    expect(find.text('Review and book'), findsOneWidget);
    expect(find.text('Mon 2 Nov, 10:00 AM'), findsOneWidget);
    expect(find.text('Mon 2 Nov, 12:00 PM'), findsOneWidget);
    expect(find.text('2 hours × ₹40.00'), findsOneWidget);
    expect(find.text('Pay at the facility'), findsOneWidget);
    expect(find.text('Pay online'), findsOneWidget);
    expect(
      find.textContaining('approved automatically when you book.'),
      findsOneWidget,
    );
    // The exact cancellation rule, in the facility's time.
    expect(find.textContaining('Free cancellation until'), findsOneWidget);
    expect(find.textContaining('9:00'), findsWidgets);

    h.http.respond(201, {'data': bookingJson()});
    h.http.stubs['/bookings/$bookingId'] = {'data': bookingJson()};
    await tester.tap(find.widgetWithText(PrimaryButton, 'Book parking'));
    await tester.pumpAndSettle();

    final create = h.http.requests.lastWhere((r) => r.method == 'POST');
    expect(create.path, '/bookings');
    expect((create.data as Map)['payment_mode'], 'on_site');
    expect((create.data as Map)['expected_total_amount'], '80.00');
    expect(create.headers['Idempotency-Key'], isNotEmpty);

    // The booking itself is the result screen.
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('BK-K2M5XCN4'), findsOneWidget);
    expect(
      find.text("You're booked. Show the reference at the facility."),
      findsOneWidget,
    );
    expect(find.text('Pay ₹80.00 at the facility'), findsOneWidget);

    // Cancelling asks first and states the consequence.
    await tester.ensureVisible(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this booking?'), findsOneWidget);
    await tester.tap(find.text('Keep booking'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);

    h.http.respond(200, {'data': bookingJson(status: 'cancelled')});
    h.http.stubs['/bookings'] = bookingsJson([
      bookingJson(status: 'cancelled'),
    ]);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Cancel booking'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('This booking was cancelled.'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);

    // Back goes to the list, never to the booking form.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Review and book'), findsNothing);
    // A cancelled booking is no longer Upcoming: it is under Past.
    expect(find.text('BK-K2M5XCN4'), findsNothing);
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('BK-K2M5XCN4'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (refund, text) in [
    (true, 'your payment refunded in full'),
    (false, "won't be refunded"),
  ]) {
    testWidgets(
      'cancelling a paid booking says whether it is refunded ($refund)',
      (tester) async {
        final h = Harness(token: validToken());
        final paid = bookingJson(
          paymentMode: 'online',
          refundIfCancelledNow: refund,
        );
        h.http.stubs['/bookings'] = bookingsJson([paid]);
        h.http.stubs['/bookings/$bookingId'] = {'data': paid};
        h.http.respond(200, {'data': userJson()});
        await tester.pumpWidget(
          ProviderScope(overrides: h.overrides, child: const App()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('BK-K2M5XCN4'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cancel booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel booking'));
        await tester.pumpAndSettle();

        expect(find.textContaining(text), findsOneWidget);
      },
    );
  }

  testWidgets('a facility that used to require approval books automatically', (
    tester,
  ) async {
    final h = await atReview(tester);

    // This facility takes online payment only: no choice is offered.
    expect(find.text('Pay at the facility'), findsNothing);
    expect(find.text('Pay online'), findsOneWidget);
    expect(
      find.textContaining(
        'Your booking is approved automatically when you book.',
      ),
      findsOneWidget,
    );

    final waitingForPayment = bookingJson(
      status: 'awaiting_payment',
      paymentMode: 'online',
      bookingMode: 'owner_approval',
      paymentDeadline: '2026-11-02T04:27:00Z',
    );
    h.http.respond(201, {'data': waitingForPayment});
    h.http.stubs['/bookings/$bookingId'] = {'data': waitingForPayment};
    await tester.tap(find.widgetWithText(PrimaryButton, 'Book parking'));
    await tester.pumpAndSettle();

    expect(find.text('Payment pending'), findsOneWidget);
    expect(
      find.textContaining('Pay by 9:57 AM to confirm this booking.'),
      findsOneWidget,
    );
    expect(find.text('Pay ₹80.00'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsNothing);
    expect(find.text('Cancel request'), findsNothing);

    h.http.respond(201, {'data': orderJson(provider: 'fake')});
    await tester.tap(find.widgetWithText(PrimaryButton, 'Pay ₹80.00'));
    await tester.pumpAndSettle();
    expect(find.text('Payment'), findsOneWidget);
    expect(
      find.text('Test server: payments are simulated and no money moves.'),
      findsOneWidget,
    );

    final paid = bookingJson(paymentMode: 'online');
    h.http
      ..respond(200, {'data': <String, Object?>{}})
      ..respond(
        200,
        paymentJson(
          orderStatus: 'succeeded',
          bookingStatus: 'confirmed',
          provider: 'fake',
        ),
      );
    h.http.stubs['/bookings/$bookingId'] = {'data': paid};
    h.http.stubs['/bookings'] = bookingsJson([paid]);
    await tester.tap(find.text('Simulate a successful payment'));
    await tester.pumpAndSettle();
    expect(find.text('Payment received'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrimaryButton, 'View booking'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Pay ₹80.00'), findsNothing);
  });

  testWidgets('when the last space was just taken, it says so and stays put', (
    tester,
  ) async {
    final h = await atReview(tester, quote: instantOnsiteQuote());

    h.http.respond(409, {
      'error': {'code': 'SLOT_UNAVAILABLE', 'message': 'Taken.'},
    });
    await tester.tap(find.widgetWithText(PrimaryButton, 'Book parking'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The last space for this time was just taken. Choose another time or facility.',
      ),
      findsOneWidget,
    );
    expect(find.text('Review and book'), findsOneWidget);
    expect(find.text('Change time'), findsOneWidget);
  });

  testWidgets('the bookings tab lists bookings, or invites the first one', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs['/bookings'] = bookingsJson(const []);
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('No bookings yet'), findsOneWidget);
    expect(find.text('Find parking'), findsOneWidget);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('No past bookings'), findsOneWidget);
    expect(find.text('Find parking'), findsNothing);
  });

  testWidgets('refreshes bookings when the app returns to the foreground', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs['/bookings'] = bookingsJson(const []);
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    final initialBookingRequests = h.http.requests
        .where((request) => request.path == '/bookings')
        .length;
    expect(initialBookingRequests, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      h.http.requests.where((request) => request.path == '/bookings').length,
      6,
    );
  });
}
