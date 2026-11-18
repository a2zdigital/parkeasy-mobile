import 'package:app/app/app.dart';
import 'package:app/core/location/location_service.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/features/owner/ui/facility_form_screen.dart';
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
    h.http.stubs['/places/search'] = {'data': <Object>[]};
    h.http.respond(200, {
      'data': userJson(roles: ['customer', 'owner']),
    });
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Requests'), findsOneWidget);
    await tester.tap(find.text('Facilities'));
    await tester.pumpAndSettle();
    return h;
  }

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  /// Lets the search-while-typing delay pass, so its search runs.
  Future<void> pause(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  /// The search button inside the name field.
  Future<void> searchName(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final button = find.byTooltip('Find on Google Maps');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.descendant(
      of: find.bySemanticsLabel(label),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  /// The API's place search finding the facility's address.
  Map<String, dynamic> placeMatch({double latitude = 12.9756}) => {
    'data': [
      {
        'id': 'mg-road',
        'name': '12 MG Road',
        'address': '12 MG Road, Bengaluru, Karnataka 560001, India',
        'latitude': latitude,
        'longitude': 77.605,
      },
    ],
  };

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

    h.http.stubs['/places/search'] = placeMatch();
    await fill(tester, 'Facility name', 'MG Road Metro Parking');
    await searchName(tester);
    // A single match is still only suggested, never chosen for the owner.
    expect(find.text('Choose your facility on Google Maps'), findsOneWidget);
    expect(find.textContaining('Selected on Google Maps'), findsNothing);
    await tester.tap(
      find.text('12 MG Road, Bengaluru, Karnataka 560001, India'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Selected on Google Maps: 12.97560, 77.60500'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.text(
        "New bookings are approved automatically. The customer's selected payment method determines whether payment is due online or at the facility.",
      ),
    );
    await tester.ensureVisible(find.text('CCTV'));
    await tester.tap(find.text('CCTV'));
    await tester.pumpAndSettle();

    h.http.respond(201, facilityJson());
    h.http.stubs[path] = facilityJson();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
    await tester.pumpAndSettle();

    final lookup = h.http.requests.singleWhere(
      (request) => request.path == '/places/search',
    );
    expect(lookup.queryParameters['query'], 'MG Road Metro Parking');
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
      'booking_mode': 'instant',
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
    await tester.ensureVisible(find.text('Set the location manually'));
    await tester.tap(find.text('Set the location manually'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adjust coordinates'));
    await tester.tap(find.text('Adjust coordinates'));
    await tester.pumpAndSettle();
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

  Future<void> openFacility(WidgetTester tester, Harness h) async {
    await tester.drag(find.byType(ListView).last, const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmIn(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a draft can be deleted after confirming', (tester) async {
    final h = await atFacilities(tester);
    h.http.stubs[list] = pageJson([facilityJson()['data']]);
    h.http.stubs[path] = facilityJson();
    await openFacility(tester, h);
    expect(find.text('Pause bookings'), findsNothing);

    await tester.dragUntilVisible(
      find.text('Delete draft'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Delete draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this draft?'), findsOneWidget);

    h.http.respond(204, <String, Object?>{});
    h.http.stubs[list] = pageJson(const []);
    await confirmIn(tester, 'Delete draft');

    final deleted = writes(h).single;
    expect(deleted.method, 'DELETE');
    expect(deleted.path, path);
    expect(find.text('No facilities yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live facility can be paused and resumed', (tester) async {
    final h = await atFacilities(tester);
    final live = facilityJson(
      status: 'approved',
      withPool: true,
      withHours: true,
    );
    h.http.stubs[list] = pageJson([live['data']]);
    h.http.stubs[path] = live;
    await openFacility(tester, h);
    expect(find.text('Delete draft'), findsNothing);

    await tester.dragUntilVisible(
      find.text('Pause bookings'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Pause bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause bookings'));
    await tester.pumpAndSettle();
    h.http.respond(
      200,
      facilityJson(
        status: 'approved',
        withPool: true,
        withHours: true,
        paused: true,
      ),
    );
    await confirmIn(tester, 'Pause bookings');

    expect(writes(h).last.path, '$path/pause');
    expect(find.textContaining('Paused.'), findsOneWidget);

    h.http.respond(200, live);
    await tester.dragUntilVisible(
      find.text('Resume bookings'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Resume bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume bookings'));
    await tester.pumpAndSettle();

    expect(writes(h).last.path, '$path/resume');
    expect(find.textContaining('Live.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing a rate stops offering it', (tester) async {
    final h = await atFacilities(tester);
    final facility = facilityJson(withPool: true);
    h.http.stubs[list] = pageJson([facility['data']]);
    h.http.stubs[path] = facility;
    await openFacility(tester, h);

    await tester.tap(find.text('40 spaces'));
    await tester.pumpAndSettle();
    await fill(tester, 'Rate per day (₹)', '');
    h.http.respond(200, <String, Object?>{'data': <String, Object?>{}});
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await tester.pumpAndSettle();

    final ended = writes(h).single;
    expect(ended.method, 'DELETE');
    expect(ended.path, '/owner/pools/01M4JQSZT0000000000000POOL/rates/daily');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused delete is explained and the facility stays', (
    tester,
  ) async {
    final h = await atFacilities(tester);
    h.http.stubs[list] = pageJson([facilityJson()['data']]);
    h.http.stubs[path] = facilityJson();
    await openFacility(tester, h);

    await tester.dragUntilVisible(
      find.text('Delete draft'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Delete draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();
    h.http.respond(409, {
      'error': {'code': 'INVALID_REVIEW_STATE', 'message': 'Not a draft.'},
    });
    await confirmIn(tester, 'Delete draft');

    expect(find.textContaining('in review'), findsWidgets);
    expect(find.text('MG Road Metro Parking'), findsWidgets);
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

  group('facility location', () {
    /// The new-facility form with a name typed. Nothing is searched until
    /// the owner leaves the name field or taps "Find on Google Maps".
    Future<Harness> atNewFacility(
      WidgetTester tester, {
      Map<String, dynamic>? places,
    }) async {
      final h = await atFacilities(tester);
      if (places != null) h.http.stubs['/places/search'] = places;
      await tester.tap(find.widgetWithText(SecondaryButton, 'Add facility'));
      await tester.pumpAndSettle();
      await fill(tester, 'Facility name', 'MG Road Metro Parking');
      await pause(tester);
      return h;
    }

    Future<void> fillAddress(
      WidgetTester tester, {
      String street = '12 MG Road',
    }) async {
      await fill(tester, 'Street address', street);
      await fill(tester, 'City', 'Bengaluru');
      await fill(tester, 'State', 'Karnataka');
      await fill(tester, 'PIN code', '560001');
      await pause(tester);
    }

    /// Scrolls the form until [text] sits clear of the bottom button, then
    /// taps it.
    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.pumpAndSettle();
      final target = find.text(text);
      final form = find
          .ancestor(of: target, matching: find.byType(Scrollable))
          .first;
      for (var i = 0; i < 12 && tester.getCenter(target).dy > 400; i++) {
        await tester.drag(form, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<RequestOptions> create(WidgetTester tester, Harness h) async {
      h.http.respond(201, facilityJson());
      h.http.stubs[path] = facilityJson();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
      await tester.pumpAndSettle();
      return writes(h).single;
    }

    Map<String, dynamic> places(List<(String, String, double, double)> items) =>
        {
          'data': [
            for (final (index, (name, address, latitude, longitude))
                in items.indexed)
              {
                'id': 'place-$index',
                'name': name,
                'address': address,
                'latitude': latitude,
                'longitude': longitude,
              },
          ],
        };

    testWidgets('all fields show at once, in order, with nothing folded away', (
      tester,
    ) async {
      await atNewFacility(tester);

      expect(find.text('More details (optional)'), findsNothing);
      double top(String text) => tester.getTopLeft(find.text(text).first).dy;
      final labels = [
        'Facility name',
        'Description (optional)',
        'Street address',
        'City',
        'State',
        'PIN code',
        'Location on the map',
        'How bookings are confirmed',
      ];
      for (var i = 1; i < labels.length; i++) {
        expect(
          top(labels[i]),
          greaterThan(top(labels[i - 1])),
          reason: '${labels[i]} comes after ${labels[i - 1]}',
        );
      }
    });

    testWidgets('a facility found on Google Maps fills the address and location', (
      tester,
    ) async {
      final h = await atNewFacility(
        tester,
        places: places([
          (
            'MG Road Metro Parking',
            'Shop 4, 12 MG Road, Ashok Nagar, Bengaluru, Karnataka 560001, India',
            12.97541,
            77.60678,
          ),
        ]),
      );
      // Found while typing: one place with the facility's own name.
      expect(find.text('Choose your facility on Google Maps'), findsNothing);
      expect(
        h.http.requests.last.queryParameters['query'],
        'MG Road Metro Parking',
      );
      // The manual options stay out of the way; the owner can still change it.
      expect(find.text('Set on map'), findsNothing);
      expect(find.text('Not the right place? Change location'), findsOneWidget);
      expect(find.text('Bengaluru'), findsWidgets);

      expect(
        find.text('Selected on Google Maps: 12.97541, 77.60678'),
        findsOneWidget,
      );
      expect(find.textContaining('Check this is the facility'), findsOneWidget);
      final created = await create(tester, h);
      expect(
        created.data,
        containsPair('address_line', 'Shop 4, 12 MG Road, Ashok Nagar'),
      );
      expect(created.data, containsPair('city', 'Bengaluru'));
      expect(created.data, containsPair('state', 'Karnataka'));
      expect(created.data, containsPair('postal_code', '560001'));
      expect(created.data, containsPair('latitude', 12.97541));
      expect(created.data, containsPair('longitude', 77.60678));
    });

    testWidgets("the provider's own address parts are used when given", (
      tester,
    ) async {
      final h = await atNewFacility(
        tester,
        places: {
          'data': [
            {
              'id': 'place-0',
              'name': 'MG Road Metro Parking',
              'address':
                  '12, Mahatma Gandhi Road, Shanthala Nagar, Bengaluru, Karnataka 560001, India',
              'latitude': 12.97541,
              'longitude': 77.60678,
              'address_line': '12, Mahatma Gandhi Road, Shanthala Nagar',
              'city': 'Bengaluru',
              'state': 'Karnataka',
              'postal_code': '560001',
            },
          ],
        },
      );

      final created = await create(tester, h);
      expect(
        created.data,
        containsPair(
          'address_line',
          '12, Mahatma Gandhi Road, Shanthala Nagar',
        ),
      );
      expect(created.data, containsPair('city', 'Bengaluru'));
      expect(created.data, containsPair('postal_code', '560001'));
    });

    testWidgets('several matches are listed and the chosen one is used', (
      tester,
    ) async {
      final h = await atNewFacility(
        tester,
        places: places([
          (
            'MG Road Parking',
            'MG Road, Bengaluru, Karnataka 560001, India',
            12.9751,
            77.6070,
          ),
          (
            'MG Road Metro Parking',
            'Trinity Circle, Bengaluru, Karnataka 560008, India',
            12.9729,
            77.6190,
          ),
        ]),
      );
      await searchName(tester);

      expect(find.byType(AppCard), findsNWidgets(3)); // two places + location
      expect(find.textContaining('Selected on Google Maps'), findsNothing);
      await tester.tap(
        find.text('Trinity Circle, Bengaluru, Karnataka 560008, India'),
      );
      await tester.pumpAndSettle();

      final created = await create(tester, h);
      expect(created.data, containsPair('latitude', 12.9729));
      expect(created.data, containsPair('postal_code', '560008'));
    });

    testWidgets('no match says so and lists the manual options in order', (
      tester,
    ) async {
      final h = await atNewFacility(tester);
      await searchName(tester);

      expect(
        find.text(
          "We couldn't find this parking facility on Google Maps. "
          'Please set its location manually.',
        ),
        findsOneWidget,
      );
      final options = [
        'Set on map',
        'Find from address',
        'Use my current location',
        'Adjust coordinates',
      ];
      final tops = [
        for (final o in options) tester.getTopLeft(find.text(o)).dy,
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: options[i]);
      }

      // Nothing is saved without a location.
      await fillAddress(tester);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
      await tester.pumpAndSettle();
      expect(
        find.text("Set the facility's location before saving."),
        findsOneWidget,
      );
      expect(writes(h), isEmpty);
    });

    testWidgets('"None of these" leads to the manual options', (tester) async {
      await atNewFacility(
        tester,
        places: places([
          (
            'Other Parking',
            'Indiranagar, Bengaluru, Karnataka 560038, India',
            12.97,
            77.64,
          ),
        ]),
      );
      await searchName(tester);
      await tapText(tester, 'None of these is my facility');

      expect(
        find.textContaining("We couldn't find this parking facility"),
        findsOneWidget,
      );
      expect(find.text('Other Parking'), findsNothing);
    });

    testWidgets('the address is looked up when asked, and shown to verify', (
      tester,
    ) async {
      final h = await atNewFacility(tester);
      await fillAddress(tester);
      h.http.stubs['/places/search'] = placeMatch();
      await tapText(tester, 'Find from address');

      expect(
        find.text('Found from the address: 12.97560, 77.60500'),
        findsOneWidget,
      );
      expect(find.textContaining('12 MG Road, Bengaluru'), findsWidgets);
      expect(
        h.http.requests.last.queryParameters['query'],
        '12 MG Road, Bengaluru, Karnataka 560001',
      );
      final created = await create(tester, h);
      expect(created.data, containsPair('latitude', 12.9756));
    });

    testWidgets('an address changed after its lookup must be confirmed again', (
      tester,
    ) async {
      final h = await atNewFacility(tester);
      await fillAddress(tester);
      h.http.stubs['/places/search'] = placeMatch();
      await tapText(tester, 'Find from address');

      await fill(tester, 'Street address', '14 MG Road');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The address changed after the location'),
        findsOneWidget,
      );
      expect(writes(h), isEmpty);

      h.http.stubs['/places/search'] = placeMatch(latitude: 12.9761);
      await tapText(tester, 'Find from address');
      final created = await create(tester, h);
      expect(created.data, containsPair('latitude', 12.9761));
    });

    testWidgets("the phone's location is used only when chosen", (
      tester,
    ) async {
      final h = await atNewFacility(tester);
      await fillAddress(tester);
      h.location.position = (latitude: 12.97601, longitude: 77.60412);
      expect(h.location.asked, 0);

      await tapText(tester, 'Use my current location');
      expect(
        find.text("Set from this phone's location: 12.97601, 77.60412"),
        findsOneWidget,
      );
      final created = await create(tester, h);
      expect(created.data, containsPair('latitude', 12.97601));
      expect(created.data, containsPair('longitude', 77.60412));
    });

    testWidgets('coordinates can be typed by hand', (tester) async {
      final h = await atNewFacility(tester);
      await fillAddress(tester);
      await tapText(tester, 'Adjust coordinates');
      await fill(tester, 'Latitude', '12.9757');
      await fill(tester, 'Longitude', '77.6061');
      await tester.pumpAndSettle();
      expect(find.text('Set to 12.97570, 77.60610'), findsOneWidget);

      final created = await create(tester, h);
      expect(created.data, containsPair('latitude', 12.9757));
      expect(created.data, containsPair('longitude', 77.6061));
    });

    testWidgets('typing waits for a pause and searches once', (tester) async {
      final h = await atFacilities(tester);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Add facility'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.bySemanticsLabel('Facility name'),
        matching: find.byType(TextField),
      );
      for (final partial in ['MG ', 'MG Ro', 'MG Road Me', 'MG Road Metro']) {
        await tester.enterText(field, partial);
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(h.http.requests.where((r) => r.path == '/places/search'), isEmpty);

      await pause(tester);
      final searches = h.http.requests
          .where((r) => r.path == '/places/search')
          .toList();
      expect(searches, hasLength(1));
      expect(searches.single.queryParameters['query'], 'MG Road Metro');
    });

    testWidgets('the search uses the address details as well', (tester) async {
      final h = await atNewFacility(tester);
      await fillAddress(tester);

      expect(
        h.http.requests.last.queryParameters['query'],
        'MG Road Metro Parking, 12 MG Road, Bengaluru, 560001',
      );
    });

    testWidgets('a place found later can be corrected', (tester) async {
      await atNewFacility(
        tester,
        places: places([
          (
            'MG Road Metro Parking',
            'MG Road, Bengaluru, Karnataka 560001, India',
            12.9756,
            77.605,
          ),
        ]),
      );
      await tapText(tester, 'Not the right place? Change location');

      expect(find.text('Set on map'), findsOneWidget);
      expect(find.text('Use my current location'), findsOneWidget);
    });

    testWidgets('a failed search says so and can be tried again', (
      tester,
    ) async {
      final h = await atFacilities(tester);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Add facility'));
      await tester.pumpAndSettle();
      h.http.stubs.remove('/places/search');
      h.http.fail(DioExceptionType.connectionError);
      await fill(tester, 'Facility name', 'MG Road Metro Parking');
      await pause(tester);

      expect(find.text('Try the search again'), findsOneWidget);
      // The owner is never stuck: the manual options are open.
      expect(find.text('Set on map'), findsOneWidget);

      h.http.stubs['/places/search'] = places([
        (
          'MG Road Metro Parking',
          'MG Road, Bengaluru, Karnataka 560001, India',
          12.9756,
          77.605,
        ),
      ]);
      await tapText(tester, 'Try the search again');
      expect(
        find.text('Selected on Google Maps: 12.97560, 77.60500'),
        findsOneWidget,
      );
    });

    testWidgets('a refused location permission is explained', (tester) async {
      final h = await atNewFacility(tester);
      h.location.failure = LocationFailure.denied;
      await tapText(tester, 'Use my current location');

      expect(
        find.textContaining('Location permission was not given'),
        findsOneWidget,
      );
      expect(find.text('Not set yet.'), findsOneWidget);
      expect(writes(h), isEmpty);
    });

    testWidgets('"never allow" offers the phone settings', (tester) async {
      final h = await atNewFacility(tester);
      h.location.failure = LocationFailure.deniedForever;
      await tapText(tester, 'Use my current location');
      await tapText(tester, 'Open settings');

      expect(h.location.settingsOpened, 1);
    });
  });

  group('splitting a Google Maps address', () {
    test('an Indian address fills street, city, state and PIN', () {
      final parts = splitPlaceAddress(
        'Shop 4, 12 MG Road, Ashok Nagar, Bengaluru, Karnataka 560001, India',
      );
      expect(parts.street, 'Shop 4, 12 MG Road, Ashok Nagar');
      expect(parts.city, 'Bengaluru');
      expect(parts.state, 'Karnataka');
      expect(parts.postalCode, '560001');
    });

    test('an address without a PIN goes whole into the street', () {
      final parts = splitPlaceAddress('Brigade Road, Bengaluru, India');
      expect(parts.street, 'Brigade Road, Bengaluru');
      expect(parts.city, isNull);
      expect(parts.postalCode, isNull);
    });
  });
}
