import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
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
      find.text('Your booking is confirmed as soon as you book.'),
      findsOneWidget,
    );

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
    expect(find.text('BK-K2M5XCN4'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a facility that needs approval sends a request, and says so', (
    tester,
  ) async {
    final h = await atReview(tester);

    // This facility takes online payment only: no choice is offered.
    expect(find.text('Pay at the facility'), findsNothing);
    expect(find.text('Pay online'), findsOneWidget);
    expect(find.textContaining('This is a request.'), findsOneWidget);

    final pending = bookingJson(
      status: 'pending_approval',
      paymentMode: 'online',
      approvalDeadline: '2026-11-02T04:48:00Z',
    );
    h.http.respond(201, {'data': pending});
    h.http.stubs['/bookings/$bookingId'] = {'data': pending};
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(
      find.text('Request sent. The owner has until 10:18 AM to answer.'),
      findsOneWidget,
    );
    expect(
      find.text("You're booked. Show the reference at the facility."),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsOneWidget);
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

    expect(find.text('No bookings yet'), findsOneWidget);
    expect(find.text('Find parking'), findsOneWidget);
  });
}
