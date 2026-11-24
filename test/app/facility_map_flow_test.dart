import 'package:app/app/app.dart';
import 'package:app/core/config/app_identity.dart';
import 'package:app/core/maps/location_picker.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Setting a facility's exact location on the OpenStreetMap map: drag the
/// pin or tap the map, confirm, and the coordinates follow.
void main() {
  const list = '/owner/parking-lots';
  const path = '$list/$facilityId';
  const pin = ValueKey('location-pin');

  Map<String, dynamic> placeMatch() => {
    'data': [
      {
        'id': 'mg-road',
        'name': '12 MG Road',
        'address': '12 MG Road, Bengaluru, Karnataka 560001, India',
        'latitude': 12.9756,
        'longitude': 77.605,
      },
    ],
  };

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

  Future<Harness> atNewFacility(
    WidgetTester tester, {
    bool withAddress = true,
  }) async {
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
    await tester.tap(find.text('Facilities'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SecondaryButton, 'Add facility'));
    await tester.pumpAndSettle();
    await fill(tester, 'Facility name', 'MG Road Metro Parking');
    if (withAddress) {
      await fill(tester, 'Street address', '12 MG Road');
      await fill(tester, 'City', 'Bengaluru');
      await fill(tester, 'State', 'Karnataka');
      await fill(tester, 'PIN code', '560001');
    }
    // Typing pauses: the name is searched, nothing matches, and the
    // manual options open.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> openMap(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Set on map'));
    await tester.tap(find.text('Set on map'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
  }

  /// The pin's coordinates as the map screen states them.
  String pinText(WidgetTester tester) => tester
      .widget<Text>(find.textContaining('Pin at '))
      .data!
      .replaceFirst('Pin at ', '');

  testWidgets('the pin starts at the address, is dragged, and is confirmed', (
    tester,
  ) async {
    final h = await atNewFacility(tester);
    h.http.stubs['/places/search'] = placeMatch();

    await openMap(tester);
    // Opened at the address found for it, with the attribution OSM needs.
    expect(find.text('Pin at 12.975600, 77.605000'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);

    await tester.drag(find.byKey(pin), const Offset(40, -30));
    await tester.pumpAndSettle();
    final moved = pinText(tester);
    expect(moved, isNot('12.975600, 77.605000'));
    final parts = moved.split(', ').map(double.parse).toList();
    // Dragged up (north) and right (east).
    expect(parts[0], greaterThan(12.9756));
    expect(parts[1], greaterThan(77.605));

    await tester.tap(find.widgetWithText(PrimaryButton, 'Confirm location'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Placed on the map: '
        '${parts[0].toStringAsFixed(5)}, ${parts[1].toStringAsFixed(5)}',
      ),
      findsOneWidget,
    );

    final lookups = h.http.requests
        .where((r) => r.path == '/places/search')
        .length;
    h.http.respond(201, facilityJson());
    h.http.stubs[path] = facilityJson();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create facility'));
    await tester.pumpAndSettle();

    // The confirmed pin is what is saved; nothing is looked up on save.
    expect(
      h.http.requests.where((r) => r.path == '/places/search'),
      hasLength(lookups),
    );
    final created = writes(h).single.data as Map;
    expect(created['latitude'], closeTo(parts[0], 0.000001));
    expect(created['longitude'], closeTo(parts[1], 0.000001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the map moves the pin there', (tester) async {
    final h = await atNewFacility(tester);
    h.http.stubs['/places/search'] = placeMatch();
    await openMap(tester);

    final map = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(map.center + const Offset(-60, 50));
    // A single tap is told from a double tap (zoom) only after a moment.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final parts = pinText(tester).split(', ').map(double.parse).toList();
    // Tapped down (south) and left (west) of the address.
    expect(parts[0], lessThan(12.9756));
    expect(parts[1], lessThan(77.605));
  });

  testWidgets('backing out of the map changes nothing', (tester) async {
    final h = await atNewFacility(tester);
    h.http.stubs['/places/search'] = placeMatch();
    await openMap(tester);
    await tester.drag(find.byKey(pin), const Offset(40, -30));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.text('Found from the address: 12.97560, 77.60500'),
      findsOneWidget,
    );
  });

  testWidgets('without an address the map opens on the default area', (
    tester,
  ) async {
    final h = await atNewFacility(tester, withAddress: false);
    await openMap(tester);

    expect(find.textContaining('only the general area'), findsOneWidget);
    // The app's configured search area (testConfig).
    expect(find.text('Pin at 12.971600, 77.594600'), findsOneWidget);
    // The general area cannot be confirmed as the facility's location.
    final confirm = find.widgetWithText(PrimaryButton, 'Confirm location');
    expect(tester.widget<PrimaryButton>(confirm).onPressed, isNull);
    final map = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(map.center + const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<PrimaryButton>(confirm).onPressed, isNotNull);
    // Only the name was searched; there was no address to look up.
    expect(
      h.http.requests
          .where((r) => r.path == '/places/search')
          .map((r) => r.queryParameters['query']),
      everyElement('MG Road Metro Parking'),
    );
  });

  test('tiles come from OpenStreetMap under its usage policy', () {
    // The real layer, not the test override.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final layer = container.read(mapTileLayerProvider) as TileLayer;

    expect(layer.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(layer.maxZoom, 19);
    expect(
      layer.tileProvider.headers['User-Agent'],
      contains(appApplicationId),
    );
  });
}
