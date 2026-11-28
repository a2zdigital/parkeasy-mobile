// Renders every screen at phone size with the real fonts, for design review.
//
//     SCREENSHOTS=1 flutter test test/screenshots/screens_test.dart
//
// Images land in build/screenshots/. Skipped in normal runs. The data is
// the test suite's own fixtures (test/support), never shipped in the app.
@Tags(['screenshots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/app/app.dart';
import 'package:app/app/router.dart';
import 'package:app/app/routes.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

final bool _enabled = Platform.environment.containsKey('SCREENSHOTS');

const String _poolId = '01M4JQSZT0000000000000POOL';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screenshots/$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<(Harness, ProviderContainer)> _app(
  WidgetTester tester, {
  List<String> roles = const ['customer'],
  bool signedIn = true,
  void Function(Harness h)? stubs,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final h = Harness(
    token: signedIn ? validToken() : null,
    now: DateTime.utc(2026, 11, 2, 4, 17),
  );
  stubs?.call(h);
  if (signedIn) h.http.respond(200, {'data': userJson(roles: roles)});
  final container = h.container();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      child: UncontrolledProviderScope(
        container: container,
        child: const App(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (h, container);
}

Future<void> _go(WidgetTester tester, ProviderContainer c, String path) async {
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

Future<void> _push(
  WidgetTester tester,
  ProviderContainer c,
  String path,
) async {
  unawaited(c.read(routerProvider).push(path));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  testWidgets('sign-in', (tester) async {
    final (h, c) = await _app(tester, signedIn: false);
    await _shoot(tester, '01_welcome');
    await _go(tester, c, Routes.phone);
    await _shoot(tester, '02_phone');
    h.http.respond(200, {
      'data': {'expires_in': 300, 'resend_in': 30},
    });
    await tester.enterText(find.byType(TextField), '9000000001');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send code'));
    await _shoot(tester, '04_otp');
    await _go(tester, c, Routes.registrationRole);
    await _shoot(tester, '03_register_role');
  }, skip: !_enabled);

  testWidgets('complete profile', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final h = Harness(token: validToken());
    h.http.respond(200, {'data': userJson(name: null, complete: false)});
    final container = h.container();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        child: UncontrolledProviderScope(
          container: container,
          child: const App(),
        ),
      ),
    );
    await _shoot(tester, '05_complete_profile');
  }, skip: !_enabled);

  testWidgets('customer', (tester) async {
    final (h, c) = await _app(
      tester,
      stubs: (h) {
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
        h.http.stubs['/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9'] = lotJson();
        h.http.stubs['/bookings'] = bookingsJson([
          bookingJson(spaceLabel: 'B1-07', checkInCode: '7KQ3MZ8D'),
          bookingJson(id: 'b2', reference: 'BK-7HQ2MN4P', status: 'completed'),
          bookingJson(id: 'b3', reference: 'BK-3XTR8VWE', status: 'cancelled'),
        ]);
        h.http.stubs['/bookings/$bookingId'] = {
          'data': bookingJson(spaceLabel: 'B1-07', checkInCode: '7KQ3MZ8D'),
        };
        h.http.stubs['/notifications'] = pageJson([
          notificationJson(),
          notificationJson(
            id: 'n2',
            type: 'booking.reminder',
            title: 'Your parking starts soon',
            read: true,
          ),
        ]);
        h.http.stubs['/notifications/unread-count'] = unreadJson(1);
      },
    );
    await _shoot(tester, '10_explore');
    await _push(tester, c, Routes.parkingLot('01M4JQSZSNAVTVCMS8A7AJ0WJ9'));
    await _shoot(tester, '11_facility');
    h.http
      ..respond(200, quoteJson())
      ..respond(200, availabilityJson());
    await tester.tap(find.widgetWithText(PrimaryButton, 'Choose time'));
    await _shoot(tester, '16_choose_time');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await _shoot(tester, '17_review');
    await _go(tester, c, Routes.bookings);
    await _shoot(tester, '12_bookings');
    await _push(tester, c, Routes.booking(bookingId));
    await _shoot(tester, '13_booking_details');
    await _go(tester, c, Routes.activity);
    await _shoot(tester, '14_activity');
    await _go(tester, c, Routes.profile);
    await _shoot(tester, '15_profile');
    expect(h, isNotNull);
  }, skip: !_enabled);

  testWidgets('owner', (tester) async {
    final (_, c) = await _app(
      tester,
      roles: ['customer', 'owner'],
      stubs: (h) {
        final request = bookingJson(status: 'pending_approval');
        h.http.stubs['/owner/bookings'] = pageJson([
          request,
          bookingJson(id: 'b2', reference: 'BK-7HQ2MN4P'),
        ]);
        h.http.stubs['/owner/bookings/$bookingId'] = {'data': bookingJson()};
        h.http.stubs['/owner/bookings/$bookingId/collection'] =
            collectionJson();
        h.http.stubs['/owner/parking-lots'] = pageJson([
          facilityJson(
            status: 'approved',
            withPool: true,
            withHours: true,
          )['data'],
        ]);
        h.http.stubs['/owner/parking-lots/$facilityId'] = facilityJson(
          status: 'approved',
          withPool: true,
          withHours: true,
        );
        h.http.stubs['/owner/parking-lot-options'] = optionsJson();
        h.http.stubs['/owner/earnings'] = earningsJson();
        h.http.stubs['/owner/payouts'] = pageJson([
          {
            'id': 'p1',
            'reference': 'PO-ABC123',
            'amount': '500.00',
            'currency': 'INR',
            'method': 'upi',
            'upi_id_masked': 'ra*******@okhdfc',
            'status': 'pending_review',
            'reviewed_at': null,
            'paid_at': null,
            'failed_at': null,
            'created_at': '2026-11-02T04:18:00Z',
          },
        ]);
        h.http.stubs['/owner/earnings/entries'] = pageJson(const []);
        h.http.stubs['/owner/application'] = ownerJson();
      },
    );
    await _shoot(tester, '20_owner_requests');
    await _push(tester, c, Routes.ownerBooking(bookingId));
    await _shoot(tester, '21_owner_booking');
    await _go(tester, c, Routes.ownerFacilities);
    await _shoot(tester, '22_owner_facilities');
    await _push(tester, c, Routes.ownerFacility(facilityId));
    await _shoot(tester, '23_owner_facility');
    await _push(tester, c, Routes.ownerFacilityHours(facilityId));
    await _shoot(tester, '27_owner_hours');
    await _go(tester, c, Routes.ownerFacilities);
    await _push(
      tester,
      c,
      Routes.ownerFacilityPool(facilityId, poolId: _poolId),
    );
    await _shoot(tester, '28_owner_pool');
    await _go(tester, c, Routes.ownerFacilities);
    await _push(tester, c, Routes.ownerFacilityEdit(facilityId));
    await _shoot(tester, '29_owner_facility_edit');
    await _go(tester, c, Routes.ownerFacilityNew);
    await _shoot(tester, '24_owner_new_facility');
    await _go(tester, c, Routes.ownerEarnings);
    await _shoot(tester, '25_owner_earnings');
    await _go(tester, c, Routes.ownerProfile);
    await _shoot(tester, '26_owner_profile');
  }, skip: !_enabled);
}
