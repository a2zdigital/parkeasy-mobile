import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Explore → facility → choose time, through the real router and screens.
void main() {
  const lotPath = '/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9';

  Future<Harness> signedIn(WidgetTester tester, Harness h) async {
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('finds a facility, opens it and sees the price for a time', (
    tester,
  ) async {
    final h = Harness(
      token: validToken(),
      now: DateTime.utc(2026, 11, 2, 4, 17),
    );
    h.http.stubs['/parking-lots'] = searchJson([
      summaryJson(vehicles: ['car', 'two_wheeler']),
      summaryJson(
        id: 'b',
        name: 'Jayanagar 4th Block Parking',
        distanceKm: 6.04,
        bookingMode: 'owner_approval',
        hourly: null,
      ),
    ]);
    h.http.stubs[lotPath] = lotJson();
    await signedIn(tester, h);

    // The list: distance, price, and the flags that matter before opening.
    expect(find.text('Near Bengaluru'), findsOneWidget);
    expect(find.text('MG Road Metro Parking'), findsOneWidget);
    expect(find.text('420 m · 12 MG Road'), findsOneWidget);
    expect(find.text('From ₹40 / hour'), findsOneWidget);
    expect(find.text('6.0 km · 12 MG Road'), findsOneWidget);
    expect(find.text('Daily rate only'), findsOneWidget);
    expect(find.text('Needs approval'), findsOneWidget);
    expect(find.text('All vehicles'), findsOneWidget);
    expect(find.text('Two wheeler'), findsOneWidget);

    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();

    // Details: the terms a customer needs before committing.
    expect(
      find.text(
        "The owner approves each booking request before it's confirmed.",
      ),
      findsOneWidget,
    );
    expect(find.text('Pay online only'), findsOneWidget);
    expect(find.text('₹40.00 / hour'), findsOneWidget);
    expect(find.text('₹250.00 / day'), findsOneWidget);
    expect(find.text('40 spaces'), findsOneWidget);
    expect(find.text('1 space'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('CCTV'), 200);
    expect(find.text('Open 24 hours'), findsOneWidget);
    expect(find.text('6:00 AM – 10:30 PM'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);

    h.http
      ..respond(200, quoteJson())
      ..respond(200, availabilityJson(left: 1));
    await tester.tap(find.widgetWithText(PrimaryButton, 'Choose time'));
    await tester.pumpAndSettle();

    // Times are on the facility's clock: 10:00 AM IST, not the test's UTC.
    expect(find.text('Mon 2 Nov, 10:00 AM'), findsOneWidget);
    expect(find.text('Mon 2 Nov, 12:00 PM'), findsOneWidget);
    expect(find.textContaining('Asia/Kolkata'), findsOneWidget);
    expect(find.text('Available · 1 space left'), findsOneWidget);
    expect(find.text('2 hours × ₹40.00'), findsOneWidget);
    expect(find.text('₹80.00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('says so when nothing is found', (tester) async {
    await signedIn(tester, Harness(token: validToken()));

    expect(find.text('No parking found'), findsOneWidget);
    expect(find.textContaining('within 25 km'), findsOneWidget);
  });

  testWidgets('explains a failed search and recovers on retry', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs.clear();
    h.http.respond(200, {'data': userJson()});
    h.http.fail(DioExceptionType.connectionError);
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );

    h.http.respond(200, searchJson([summaryJson()]));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('MG Road Metro Parking'), findsOneWidget);
  });

  testWidgets('a closed window is explained instead of priced', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    h.http.stubs[lotPath] = lotJson();
    await signedIn(tester, h);
    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();

    h.http.respond(422, {
      'error': {'code': 'OUTSIDE_OPERATING_HOURS', 'message': 'Closed.'},
    });
    await tester.tap(find.widgetWithText(PrimaryButton, 'Choose time'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The facility is closed for part of this time. Check its opening hours.',
      ),
      findsOneWidget,
    );
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('the list holds at a small screen and double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final h = Harness(token: validToken());
    h.http.stubs['/parking-lots'] = searchJson([
      summaryJson(
        name: 'A very long facility name that will certainly need two lines',
        bookingMode: 'owner_approval',
      ),
    ]);
    await signedIn(tester, h);

    expect(tester.takeException(), isNull);
  });
}
