import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/payment/state/payment_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Bookings → a booking waiting for payment → pay → confirmed, through the
/// real router and screens, on a server with the simulated provider.
void main() {
  Future<Harness> atBooking(WidgetTester tester) async {
    final h = Harness(token: validToken());
    final waiting = bookingJson(
      status: 'awaiting_payment',
      paymentMode: 'online',
      paymentDeadline: '2026-11-02T04:28:00Z',
    );
    h.http.stubs['/bookings'] = bookingsJson([waiting]);
    h.http.stubs['/bookings/$bookingId'] = {'data': waiting};
    h.http.respond(200, {'data': userJson()});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          pollDelayProvider.overrideWithValue((_) async {}),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('pays for a waiting booking and sees it confirmed', (
    tester,
  ) async {
    final h = await atBooking(tester);

    expect(find.text('Payment pending'), findsOneWidget);
    expect(
      find.text(
        'Pay by 9:58 AM to confirm this booking. After that the space is released.',
      ),
      findsOneWidget,
    );

    // The amount is on the button.
    h.http.respond(201, {'data': orderJson(provider: 'fake')});
    await tester.tap(find.widgetWithText(PrimaryButton, 'Pay ₹80.00'));
    await tester.pumpAndSettle();

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
    expect(
      find.text('₹80.00 paid. Your booking is confirmed.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(PrimaryButton, 'View booking'));
    await tester.pumpAndSettle();

    // Back on the booking, reloaded from the API: confirmed, nothing to pay.
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Pay ₹80.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed payment says so and offers another try', (
    tester,
  ) async {
    final h = await atBooking(tester);

    h.http.respond(201, {'data': orderJson(provider: 'fake')});
    await tester.tap(find.widgetWithText(PrimaryButton, 'Pay ₹80.00'));
    await tester.pumpAndSettle();

    h.http
      ..respond(200, {'data': <String, Object?>{}})
      ..respond(200, paymentJson(orderStatus: 'failed', provider: 'fake'));
    await tester.tap(find.text('Simulate a failed payment'));
    await tester.pumpAndSettle();

    expect(find.text("Payment didn't go through"), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Try again'), findsOneWidget);
    expect(find.text('Payment received'), findsNothing);
  });

  testWidgets('a booking that expired cannot be paid, and says why', (
    tester,
  ) async {
    final h = await atBooking(tester);

    h.http.respond(409, {
      'error': {'code': 'BOOKING_EXPIRED', 'message': 'Expired.'},
    });
    await tester.tap(find.widgetWithText(PrimaryButton, 'Pay ₹80.00'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This booking is no longer waiting for payment. Book again to get a space.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(PrimaryButton, 'Try again'), findsNothing);
  });
}
