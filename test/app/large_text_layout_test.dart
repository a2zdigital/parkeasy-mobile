import 'package:app/app/app.dart';
import 'package:app/app/router.dart';
import 'package:app/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// At 150% text on a small phone the redesigned screens still lay out:
/// any overflow fails the test.
void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    Harness h, {
    List<String> roles = const ['customer'],
  }) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    h.http.respond(200, {'data': userJson(roles: roles)});
    final container = h.container();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String path) async {
    c.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  testWidgets('customer screens', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    h.http.stubs['/bookings'] = bookingsJson([
      bookingJson(spaceLabel: 'B1-07', checkInCode: '7KQ3MZ8D'),
    ]);
    h.http.stubs['/bookings/$bookingId'] = {
      'data': bookingJson(spaceLabel: 'B1-07', checkInCode: '7KQ3MZ8D'),
    };
    final c = await start(tester, h);

    for (final path in [
      Routes.bookings,
      Routes.booking(bookingId),
      Routes.profile,
    ]) {
      await go(tester, c, path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });

  testWidgets('owner screens', (tester) async {
    final h = Harness(token: validToken());
    h.http.stubs['/owner/bookings'] = pageJson([
      bookingJson(status: 'pending_approval'),
    ]);
    h.http.stubs['/owner/parking-lots'] = pageJson([
      facilityJson(status: 'approved', withPool: true)['data'],
    ]);
    h.http.stubs['/owner/earnings'] = earningsJson();
    h.http.stubs['/owner/payouts'] = pageJson(const []);
    h.http.stubs['/owner/earnings/entries'] = pageJson(const []);
    final c = await start(tester, h, roles: ['customer', 'owner']);

    expect(tester.takeException(), isNull);
    for (final path in [
      Routes.ownerFacilities,
      Routes.ownerEarnings,
      Routes.ownerProfile,
    ]) {
      await go(tester, c, path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}
