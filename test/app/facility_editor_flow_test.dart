import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// An owner creates a facility, gives it spaces and hours, and submits it,
/// through the real router and screens.
void main() {
  const list = '/owner/parking-lots';
  const path = '$list/$facilityId';

  Future<Harness> atFacilities(WidgetTester tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/owner/bookings'] = pageJson(const []);
    h.http.stubs[list] = pageJson(const []);
    h.http.stubs['/owner/parking-lot-options'] = optionsJson();
    h.http.respond(200, {
      'data': userJson(roles: ['customer', 'owner']),
    });
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner area'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facilities'));
    await tester.pumpAndSettle();
    return h;
  }

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.descendant(
      of: find.bySemanticsLabel(label),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  testWidgets('creates a facility, sets it up and submits it for review', (
    tester,
  ) async {
    final h = await atFacilities(tester);
    expect(find.text('No facilities yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(SecondaryButton, 'Add facility'));
    await tester.pumpAndSettle();
    expect(find.text('New facility'), findsOneWidget);

    // An empty form says what is missing and sends nothing.
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
    await tester.pumpAndSettle();
    expect(find.text('This is needed.'), findsWidgets);
    expect(writes(h), isEmpty);

    await fill(tester, 'Facility name', 'MG Road Metro Parking');
    await fill(tester, 'Street address', '12 MG Road');
    await fill(tester, 'City', 'Bengaluru');
    await fill(tester, 'State', 'Karnataka');
    await fill(tester, 'PIN code', '560001');
    await fill(tester, 'Latitude', '12.9756');
    await fill(tester, 'Longitude', '77.605');
    await tester.ensureVisible(find.text('After I approve'));
    await tester.tap(find.text('After I approve'));
    await tester.ensureVisible(find.text('CCTV'));
    await tester.tap(find.text('CCTV'));
    await tester.pumpAndSettle();

    h.http.respond(201, facilityJson());
    h.http.stubs[path] = facilityJson();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
    await tester.pumpAndSettle();

    final created = writes(h).single;
    expect(created.path, list);
    expect(created.data, {
      'name': 'MG Road Metro Parking',
      'address_line': '12 MG Road',
      'city': 'Bengaluru',
      'state': 'Karnataka',
      'postal_code': '560001',
      'latitude': 12.9756,
      'longitude': 77.605,
      'booking_mode': 'owner_approval',
      'accepts_online_payment': true,
      'accepts_onsite_payment': true,
      'amenities': ['cctv'],
    });

    // The new draft's set-up screen, which says what is still missing.
    expect(find.textContaining('This facility is a draft'), findsOneWidget);
    expect(
      find.text('Add at least one vehicle type with a rate.'),
      findsOneWidget,
    );

    // Spaces and rates.
    await tester.tap(find.text('Add a vehicle type'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number from 1.'), findsOneWidget);
    expect(find.text('Set at least one rate.'), findsOneWidget);

    await fill(tester, 'Number of spaces', '40');
    await fill(tester, 'Rate per hour (₹)', '40');
    final pool = (lotJson()['data']! as Map)['pools'] as List<Object?>;
    h.http
      ..respond(201, {'data': pool.first})
      ..respond(200, {'data': pool.first});
    h.http.stubs[path] = facilityJson(withPool: true);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('40 spaces'), findsOneWidget);
    expect(find.text('₹40.00 / hour'), findsOneWidget);

    // Opening hours.
    await tester.dragUntilVisible(
      find.text('Opening hours are not set.'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Edit').last);
    await tester.pumpAndSettle();
    expect(find.text('Monday'), findsOneWidget);
    await tester.tap(find.text('Open 24 hours every day'));
    h.http.respond(200, {'data': <String, Object?>{}});
    h.http.stubs[path] = facilityJson(withPool: true, withHours: true);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    final hours = writes(h).last;
    expect(hours.path, '$path/operating-hours');
    expect((hours.data as Map)['hours'], hasLength(7));

    // Submit.
    h.http.respond(200, {'data': <String, Object?>{}});
    h.http.stubs[path] = facilityJson(
      status: 'pending',
      withPool: true,
      withHours: true,
    );
    await tester.tap(find.widgetWithText(PrimaryButton, 'Submit for review'));
    await tester.pumpAndSettle();

    expect(writes(h).last.path, '$path/submit');
    expect(find.textContaining('Sent for review'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);
    expect(find.text('Add a vehicle type'), findsNothing, reason: 'locked');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an incomplete facility cannot be submitted, and says what it needs',
    (tester) async {
      final h = await atFacilities(tester);
      h.http.stubs[list] = pageJson([facilityJson()['data']]);
      h.http.stubs[path] = facilityJson();
      await tester.drag(find.byType(ListView).last, const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();

      h.http.respond(409, {
        'error': {'code': 'PARKING_LOT_INCOMPLETE', 'message': 'Incomplete.'},
      });
      await tester.tap(find.widgetWithText(PrimaryButton, 'Submit for review'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not ready to submit yet'), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Submit for review'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the API validation is shown on the field it names', (
    tester,
  ) async {
    final h = await atFacilities(tester);
    await tester.tap(find.widgetWithText(SecondaryButton, 'Add facility'));
    await tester.pumpAndSettle();

    await fill(tester, 'Facility name', 'AB');
    await fill(tester, 'Street address', '12 MG Road');
    await fill(tester, 'City', 'Bengaluru');
    await fill(tester, 'State', 'Karnataka');
    await fill(tester, 'PIN code', '560001');
    await fill(tester, 'Latitude', '12.9756');
    await fill(tester, 'Longitude', '77.605');
    h.http.respond(422, {
      'error': {
        'code': 'VALIDATION_FAILED',
        'message': 'Invalid.',
        'details': {
          'name': ['The name field must be at least 3 characters.'],
        },
      },
    });
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
    await tester.pumpAndSettle();

    expect(
      find.text('The name field must be at least 3 characters.'),
      findsOneWidget,
    );
    expect(find.text('New facility'), findsOneWidget);
  });

  testWidgets('finding a booking by its reference at the gate', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/owner/bookings'] = pageJson([bookingJson()]);
    h.http.respond(200, {
      'data': userJson(roles: ['customer', 'owner']),
    });
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner area'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bk-k2m5xcn4');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final query = h.http.requests
        .lastWhere((r) => r.path == '/owner/bookings')
        .uri
        .queryParameters;
    expect(query['filter[reference]'], 'BK-K2M5XCN4');
    expect(query.containsKey('filter[status]'), isFalse);
    expect(find.text('Requests'), findsNothing);
  });
}
