import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Owner check-out at the gate: scan or type the customer's check-out code,
/// see the booking the API verified, confirm, done.
void main() {
  // A scanned check-out pass, sent exactly as scanned (its signature is
  // lower case and must never be upper-cased).
  const pass = 'PE2.01M4JQYWW2WEFYAASEC49S6PW3.29845123.9f2c0a1b2c3d4e5f';

  final parked = bookingJson(
    status: 'parked',
    checkedInAt: '2026-11-02T04:35:00Z',
    spaceLabel: 'B1-07',
  );

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  Map<String, dynamic> body(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);

  /// Opens the owner's gate screen in check-out mode.
  Future<Harness> atCheckOut(WidgetTester tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/owner/bookings'] = pageJson([parked]);
    h.http.stubs['/owner/bookings/$bookingId'] = {'data': parked};
    h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
    h.http.respond(200, {
      'data': userJson(roles: ['customer', 'owner']),
    });
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BK-K2M5XCN4'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(
      SecondaryButton,
      'Check out with a code',
    );
    await tester.dragUntilVisible(
      button,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text("Customer's check-out code"), findsOneWidget);
    return h;
  }

  testWidgets(
    'scans the checkout QR, shows the verified booking, then checks out',
    (tester) async {
      final h = await atCheckOut(tester);
      h.scanner.next = pass;
      final overdue = {
        ...parked,
        'overstay': {
          'minutes': 40,
          'parking_amount': '40.00',
          'gst_amount': '0.00',
          'total_amount': '40.00',
        },
      };
      final completed = {
        ...overdue,
        'status': 'completed',
        'checked_out_at': '2026-11-02T07:10:00Z',
      };
      h.http.respond(200, {'data': overdue});
      h.http.respond(200, {'data': completed});
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': completed};

      await tester.tap(find.text('Scan QR code'));
      await tester.pumpAndSettle();

      // Verified by the API, shown before anything changes.
      expect(find.text('Confirm check-out'), findsWidgets);
      expect(find.text('BK-K2M5XCN4'), findsWidgets);
      expect(find.text('MG Road Metro Parking'), findsWidgets);
      expect(
        find.text(
          'Stayed 40 min past the booking. Extra charge: ₹40.00. Collect it before the vehicle leaves.',
        ),
        findsOneWidget,
      );
      expect(writes(h).single.path, '/owner/check-out/verify');

      // Extra time is due: nothing is marked paid until a method is chosen.
      final collected = find.widgetWithText(
        PrimaryButton,
        'Collected, check out',
      );
      expect(tester.widget<PrimaryButton>(collected).onPressed, isNull);
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();
      // A method alone is not enough: the money must be confirmed in hand.
      expect(tester.widget<PrimaryButton>(collected).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('extra-time-collected')));
      await tester.pumpAndSettle();
      expect(
        find.text('I have collected ₹40.00 from the customer'),
        findsOneWidget,
      );
      expect(tester.widget<PrimaryButton>(collected).onPressed, isNotNull);
      await tester.ensureVisible(collected);
      await tester.pumpAndSettle();
      await tester.tap(collected);
      await tester.pumpAndSettle();

      final sent = writes(h);
      expect(sent.map((r) => r.path), [
        '/owner/check-out/verify',
        '/owner/check-out',
      ]);
      expect(body(sent.first), {'code': pass});
      expect(body(sent.last), {
        'code': pass,
        'extra_time_payment_method': 'upi',
        'expected_extra_time_amount': '40.00',
      });
      expect(find.text('Checked out BK-K2M5XCN4.'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
    },
  );

  testWidgets('a typed code is checked, and backing out sends no check-out', (
    tester,
  ) async {
    final h = await atCheckOut(tester);
    h.http.respond(200, {'data': parked});

    await tester.enterText(find.byType(TextField).last, 'q7m3-k9tp');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm check-out'), findsWidgets);

    await tester.tap(find.text('Keep booking'));
    await tester.pumpAndSettle();

    expect(writes(h).single.path, '/owner/check-out/verify');
    expect(body(writes(h).single), {'code': 'Q7M3K9TP'});
  });

  for (final (code, status, message) in [
    (
      'CHECK_OUT_CODE_NOT_FOUND',
      404,
      'No parked booking here has this check-out code. Check the code and try again.',
    ),
    (
      'GATE_PASS_EXPIRED',
      409,
      'This QR code has expired. Ask the customer to show the current one, or type their code.',
    ),
    (
      'CHECK_IN_CODE_AT_CHECK_OUT',
      409,
      "That's the check-in code. Ask the customer for the check-out code now shown on their booking.",
    ),
    (
      'INTERNAL_ERROR',
      500,
      'Something went wrong on our side, so the booking is still parked and nothing was recorded. Try again in a moment.',
    ),
    (
      'ALREADY_CHECKED_OUT',
      409,
      "This booking has already been checked out. The code can't be used again.",
    ),
  ]) {
    testWidgets('$code is explained and nothing is checked out', (
      tester,
    ) async {
      final h = await atCheckOut(tester);
      h.http.respond(status, {
        'error': {'code': code, 'message': 'No.'},
      });

      await tester.enterText(find.byType(TextField).last, 'Q7M3K9TP');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.text('Confirm check-out'), findsNothing);
      expect(writes(h).map((r) => r.path), ['/owner/check-out/verify']);
    });
  }

  testWidgets('a failed checkout leaves the panel ready to try again', (
    tester,
  ) async {
    final h = await atCheckOut(tester);
    h.http.respond(200, {'data': parked});
    h.http.respond(500, {
      'error': {'code': 'INTERNAL_ERROR', 'message': 'No.'},
    });
    await tester.enterText(find.byType(TextField).last, 'Q7M3K9TP');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Confirm check-out'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Something went wrong on our side'),
      findsOneWidget,
    );
    final button = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Check out'),
    );
    expect(button.isLoading, isFalse);
    expect(button.onPressed, isNotNull);
  });

  group('paid at the facility', () {
    final due = {...parked, 'booking_payment_status': 'due_at_facility'};

    Future<void> openSheet(WidgetTester tester, Harness h) async {
      h.http.respond(200, {'data': due});
      await tester.enterText(find.byType(TextField).last, 'q7m3 k9tp');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
      await tester.pumpAndSettle();
    }

    Finder confirm() =>
        find.widgetWithText(PrimaryButton, 'Collected, check out');

    Future<void> collect(WidgetTester tester, String method) async {
      await tester.tap(find.text(method).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-payment-collected')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-payment-collected')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the amount due and records it only once confirmed', (
      tester,
    ) async {
      final h = await atCheckOut(tester);
      await openSheet(tester, h);

      expect(
        find.text(
          'To pay at the facility: ₹80.00. Collect it before the vehicle leaves.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<PrimaryButton>(confirm()).onPressed, isNull);
      await tester.tap(find.text('Cash').first);
      await tester.pumpAndSettle();
      // A method alone never marks it paid.
      expect(tester.widget<PrimaryButton>(confirm()).onPressed, isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-payment-collected')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-payment-collected')));
      await tester.pumpAndSettle();
      expect(
        find.text('I have received ₹80.00 for this booking'),
        findsOneWidget,
      );

      final completed = {
        ...due,
        'status': 'completed',
        'booking_payment_status': 'collected_at_facility',
        'checked_out_at': '2026-11-02T06:40:00Z',
      };
      h.http.respond(200, {'data': completed});
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': completed};
      await tester.ensureVisible(confirm());
      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(body(writes(h).last), {
        'code': 'Q7M3K9TP',
        'booking_payment_method': 'cash',
        'booking_payment_collected': true,
        'booking_payment_amount': '80.00',
      });
      expect(find.text('Checked out BK-K2M5XCN4.'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
    });

    for (final (code, status, message) in [
      (
        'BOOKING_PAYMENT_REQUIRED',
        422,
        'Payment not yet received. Collect the amount due, choose how it was paid and confirm it, or ask the customer to finish paying online.',
      ),
      (
        'BOOKING_PAYMENT_AMOUNT_MISMATCH',
        422,
        "That amount doesn't match what's due for this booking. Nothing was recorded. Check the booking and try again.",
      ),
    ]) {
      testWidgets('$code is explained and the booking stays parked', (
        tester,
      ) async {
        final h = await atCheckOut(tester);
        await openSheet(tester, h);
        await collect(tester, 'UPI');
        h.http.respond(status, {
          'error': {'code': code, 'message': 'No.'},
        });
        await tester.ensureVisible(confirm());
        await tester.tap(confirm());
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.text('Checked out BK-K2M5XCN4.'), findsNothing);
      });
    }

    testWidgets('a timeout is explained, and trying again checks out', (
      tester,
    ) async {
      final h = await atCheckOut(tester);
      await openSheet(tester, h);
      await collect(tester, 'Card');
      h.http.fail(DioExceptionType.receiveTimeout);
      await tester.ensureVisible(confirm());
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The connection timed out before checkout finished. The booking is still parked. Check the connection and try again.',
        ),
        findsOneWidget,
      );

      // Again: verify, confirm with the payment, done.
      await openSheet(tester, h);
      await collect(tester, 'Card');
      final completed = {
        ...due,
        'status': 'completed',
        'checked_out_at': '2026-11-02T06:40:00Z',
      };
      h.http.respond(200, {'data': completed});
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': completed};
      await tester.ensureVisible(confirm());
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(find.text('Checked out BK-K2M5XCN4.'), findsOneWidget);
      expect(body(writes(h).last)['booking_payment_method'], 'card');
    });

    testWidgets('an unpaid online booking cannot be checked out', (
      tester,
    ) async {
      final h = await atCheckOut(tester);
      h.http.respond(200, {
        'data': {
          ...parked,
          'payment_mode': 'online',
          'booking_payment_status': 'unpaid',
        },
      });
      await tester.enterText(find.byType(TextField).last, 'Q7M3K9TP');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "The online payment for this booking hasn't gone through, so it can't be checked out. Ask the customer to complete the payment in the app.",
        ),
        findsOneWidget,
      );
      final button = find.widgetWithText(PrimaryButton, 'Confirm check-out');
      expect(tester.widget<PrimaryButton>(button).onPressed, isNull);
      expect(writes(h).map((r) => r.path), ['/owner/check-out/verify']);
    });

    testWidgets('a paid online booking checks out without payment fields', (
      tester,
    ) async {
      final h = await atCheckOut(tester);
      final paid = {
        ...parked,
        'payment_mode': 'online',
        'booking_payment_status': 'paid_online',
      };
      h.http.respond(200, {'data': paid});
      h.http.respond(200, {
        'data': {
          ...paid,
          'status': 'completed',
          'checked_out_at': '2026-11-02T06:40:00Z',
        },
      });
      await tester.enterText(find.byType(TextField).last, 'Q7M3K9TP');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-payment-collected')),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(PrimaryButton, 'Confirm check-out'));
      await tester.pumpAndSettle();

      expect(body(writes(h).last), {'code': 'Q7M3K9TP'});
    });
  });
}
