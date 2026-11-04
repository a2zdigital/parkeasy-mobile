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

  testWidgets('shows an empty state with a blank location search field', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    await signedIn(tester, h);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(field.decoration?.hintText, 'Enter a location');
    expect(
      h.http.requests.any(
        (request) => request.uri.path == '/api/v1/places/search',
      ),
      isFalse,
    );
    expect(find.text('No parking found'), findsOneWidget);
    expect(
      find.text(
        'No parking is available near this location yet. Try another location.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('typing and clearing do not search for places', (tester) async {
    final h = Harness(token: validToken());
    await signedIn(tester, h);

    await tester.enterText(find.byType(TextField), 'Whitefield');
    await tester.pump();

    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Whitefield');
    expect(find.text('Near Bengaluru'), findsOneWidget);
    expect(
      h.http.requests.where(
        (request) => request.uri.path == '/api/v1/places/search',
      ),
      isEmpty,
    );

    await tester.tap(find.byTooltip('Clear location search'));
    await tester.pump();

    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(field.decoration?.hintText, 'Enter a location');
    expect(find.text('Near Bengaluru'), findsOneWidget);
    expect(
      h.http.requests.where(
        (request) => request.uri.path == '/api/v1/places/search',
      ),
      isEmpty,
    );
  });

  testWidgets('submitting the field requests place matches', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/places/search'] = {
      'data': [
        {
          'id': 'whitefield',
          'name': 'Whitefield',
          'address': 'Whitefield, Bengaluru, Karnataka, India',
          'latitude': 12.9698,
          'longitude': 77.75,
        },
      ],
    };
    await signedIn(tester, h);

    await tester.enterText(find.byType(TextField), 'Whitefield');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final placeRequest = h.http.requests.singleWhere(
      (request) => request.uri.path == '/api/v1/places/search',
    );
    expect(placeRequest.method, 'GET');
    expect(placeRequest.uri.queryParameters['query'], 'Whitefield');
    expect(
      find.text('Whitefield, Bengaluru, Karnataka, India'),
      findsOneWidget,
    );
    expect(find.text('Near Bengaluru'), findsOneWidget);
  });

  testWidgets('shows a friendly message when no places match', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/places/search'] = {'data': <Object>[]};
    await signedIn(tester, h);

    await tester.enterText(find.byType(TextField), 'Nowhere');
    await tester.tap(find.byTooltip('Find location'));
    await tester.pumpAndSettle();

    expect(
      find.text('No matching places found. Try another location.'),
      findsOneWidget,
    );
    expect(find.text('Near Bengaluru'), findsOneWidget);
  });

  testWidgets('searches near a selected place', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    h.http.stubs['/places/search'] = {
      'data': [
        {
          'id': 'whitefield',
          'name': 'Whitefield',
          'address': 'Whitefield, Bengaluru, Karnataka, India',
          'latitude': 12.9698,
          'longitude': 77.75,
        },
      ],
    };
    await signedIn(tester, h);

    await tester.enterText(find.byType(TextField), 'Whitefield');
    await tester.tap(find.byTooltip('Find location'));
    await tester.pumpAndSettle();

    expect(find.text('Near Bengaluru'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Whitefield',
    );
    expect(
      find.text('Whitefield, Bengaluru, Karnataka, India'),
      findsOneWidget,
    );
    expect(find.text('Google Maps'), findsOneWidget);

    await tester.tap(find.text('Whitefield').last);
    await tester.pumpAndSettle();

    expect(find.text('Near Whitefield'), findsOneWidget);
    expect(find.text('MG Road Metro Parking'), findsOneWidget);
    final parkingSearch = h.http.requests.lastWhere(
      (request) => request.uri.path == '/api/v1/parking-lots',
    );
    expect(parkingSearch.uri.queryParameters['lat'], '12.9698');
    expect(parkingSearch.uri.queryParameters['lng'], '77.75');
    expect(parkingSearch.uri.queryParameters['radius_km'], '25.0');
    expect(parkingSearch.uri.queryParameters['page'], '1');

    await tester.tap(find.text('Use default location'));
    await tester.pumpAndSettle();

    expect(find.text('Near Bengaluru'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('shows a place-search failure with its own request reference', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    await signedIn(tester, h);

    h.http.respond(503, {
      'error': {
        'code': 'SERVICE_UNAVAILABLE',
        'message': 'Place lookup unavailable.',
        'request_id': 'place-search-ref',
      },
    });
    await tester.enterText(find.byType(TextField), 'Whitefield');
    await tester.tap(find.byTooltip('Find location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Reference: place-search-ref'), findsOneWidget);
    expect(
      h.http.requests.where(
        (request) => request.uri.path == '/api/v1/places/search',
      ),
      hasLength(1),
    );
    expect(
      h.http.requests.where(
        (request) => request.uri.path == '/api/v1/parking-lots',
      ),
      hasLength(1),
      reason: 'Place-search failure must not trigger another parking search.',
    );
  });

  testWidgets('shows a parking-search failure with its own request reference', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs.remove('/parking-lots');
    h.http.respond(200, {'data': userJson()});
    h.http.respond(500, {
      'error': {
        'code': 'INTERNAL_ERROR',
        'message': 'Search failed.',
        'request_id': 'parking-search-ref',
      },
    });
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Reference: parking-search-ref'), findsOneWidget);
    expect(
      h.http.requests.where(
        (request) => request.uri.path == '/api/v1/parking-lots',
      ),
      hasLength(1),
    );
    expect(
      h.http.requests.where(
        (request) => request.uri.path == '/api/v1/places/search',
      ),
      isEmpty,
    );
  });

  testWidgets('shows the no-match state when a vehicle filter has no results', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    h.http.stubs['/parking-lots'] = searchJson([
      summaryJson(vehicles: ['car']),
    ]);
    await signedIn(tester, h);
    h.http.stubs.remove('/parking-lots');
    h.http.respond(200, searchJson(const []));

    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();

    expect(find.text('No matching parking found'), findsOneWidget);
    expect(
      find.text('Try another vehicle type or increase the search radius.'),
      findsOneWidget,
    );
    final request = h.http.requests.lastWhere(
      (item) => item.uri.path == '/api/v1/parking-lots',
    );
    expect(request.uri.queryParameters['filter[vehicle_type]'], 'car');
    expect(request.uri.queryParameters['radius_km'], '25.0');
  });

  testWidgets('explains a failed search and recovers on retry', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs.remove('/parking-lots');
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
