import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:app/core/location/location_service.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Device location, QR codes and push-token registration, through the
/// real router, with the phone's location, camera and Firebase faked.
void main() {
  Future<void> start(
    WidgetTester tester,
    Harness h, {
    List<String> roles = const ['customer'],
    bool tokenAccepted = false,
  }) async {
    h.http.respond(200, {'data': userJson(roles: roles)});
    // The push-token registration that follows sign-in.
    if (tokenAccepted) h.http.respond(204, '');
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> body(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);

  RequestOptions lastSearch(Harness h) => h.http.requests.lastWhere(
    (request) => request.uri.path == '/api/v1/parking-lots',
  );

  group('device location', () {
    testWidgets('searches around the phone when asked', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
      await start(tester, h);
      // Nothing is asked until the user taps.
      expect(h.location.asked, 0);
      expect(lastSearch(h).uri.queryParameters['lat'], '12.9716');

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(h.location.asked, 1);
      expect(find.text('Near your location'), findsOneWidget);
      expect(lastSearch(h).uri.queryParameters['lat'], '12.9352');
      expect(lastSearch(h).uri.queryParameters['lng'], '77.6245');

      await tester.tap(find.text('Use default location'));
      await tester.pumpAndSettle();
      expect(lastSearch(h).uri.queryParameters['lat'], '12.9716');
    });

    for (final (failure, message) in [
      (LocationFailure.denied, 'Allow location to find parking'),
      (LocationFailure.serviceOff, 'Location is switched off'),
      (LocationFailure.unavailable, "Your location couldn't be found"),
    ]) {
      testWidgets('explains a refusal and keeps place search ($failure)', (
        tester,
      ) async {
        final h = Harness(token: validToken());
        h.location.failure = failure;
        await start(tester, h);
        final searches = h.http.requests.length;

        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();

        expect(find.textContaining(message), findsOneWidget);
        expect(find.text('Open settings'), findsNothing);
        expect(h.http.requests.length, searches);
      });
    }

    testWidgets('"never" offers the app settings', (tester) async {
      final h = Harness(token: validToken());
      h.location.failure = LocationFailure.deniedForever;
      await start(tester, h);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(h.location.settingsOpened, 1);
    });
  });

  group('QR codes', () {
    testWidgets('the customer sees the code as a QR code and as text', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      final booking = bookingJson(checkInCode: '7KQ3MZ8D');
      h.http.stubs['/bookings'] = bookingsJson([booking]);
      h.http.stubs['/bookings/$bookingId'] = {'data': booking};
      await start(tester, h);
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BK-K2M5XCN4'));
      await tester.pumpAndSettle();

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.semanticsLabel, 'QR code for checking in');
      expect(find.text('7KQ3 MZ8D'), findsOneWidget);
    });

    testWidgets('the owner scans the QR code and the booking is checked in', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      final confirmed = bookingJson();
      h.http.stubs['/owner/bookings'] = pageJson([confirmed]);
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': confirmed};
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('BK-K2M5XCN4'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(
        SecondaryButton,
        'Check in with a code',
      );
      await tester.dragUntilVisible(
        button,
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Backing out of the camera sends nothing.
      await tester.tap(find.widgetWithText(SecondaryButton, 'Scan QR code'));
      await tester.pumpAndSettle();
      expect(h.scanner.scans, 1);
      expect(h.http.requests.where((r) => r.method == 'POST'), isEmpty);

      final checkedIn = bookingJson(checkedInAt: '2026-11-02T04:35:00Z');
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': checkedIn};
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      h.http.respond(200, {'data': checkedIn});
      h.scanner.next = '7KQ3MZ8D';
      await tester.tap(find.widgetWithText(SecondaryButton, 'Scan QR code'));
      await tester.pumpAndSettle();

      final sent = h.http.requests.singleWhere((r) => r.method == 'POST');
      expect(sent.path, '/owner/check-in');
      expect(body(sent), {'code': '7KQ3MZ8D'});
      expect(find.text('BK-K2M5XCN4'), findsOneWidget);
    });
  });

  group('push notifications', () {
    List<RequestOptions> tokenCalls(Harness h) =>
        h.http.requests.where((r) => r.path == '/me/push-token').toList();

    testWidgets('without Firebase files nothing is registered', (tester) async {
      final h = Harness(token: validToken());
      await start(tester, h);

      expect(tokenCalls(h), isEmpty);
    });

    testWidgets('registers the device after sign-in and on a new token', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.push.configured = true;
      await start(tester, h, tokenAccepted: true);
      await tester.pumpAndSettle();

      final first = tokenCalls(h).single;
      expect(first.method, 'PUT');
      expect(body(first), {
        'token': 'fcm-token-0000000000000001',
        'platform': 'android',
      });

      h.http.respond(204, '');
      h.push.refreshes.add('fcm-token-0000000000000002');
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(body(tokenCalls(h).last)['token'], 'fcm-token-0000000000000002');
    });

    testWidgets('a refused permission registers nothing', (tester) async {
      final h = Harness(token: validToken());
      h.push
        ..configured = true
        ..allowed = false;
      await start(tester, h);
      await tester.pumpAndSettle();

      expect(tokenCalls(h), isEmpty);
    });

    testWidgets('signing out removes the token before the session ends', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.push.configured = true;
      await start(tester, h, tokenAccepted: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      h.http
        ..respond(204, '')
        ..respond(200, {'data': <String, Object?>{}});
      await tester.tap(find.widgetWithText(PrimaryButton, 'Sign out'));
      await tester.pumpAndSettle();

      final removal = tokenCalls(h).last;
      expect(removal.method, 'DELETE');
      expect(body(removal), {'token': 'fcm-token-0000000000000001'});
      expect(removal.headers['Authorization'], isNotNull);
      final logout = h.http.requests.indexWhere(
        (r) => r.path == '/auth/logout',
      );
      expect(h.http.requests.indexOf(removal), lessThan(logout));
      expect(h.push.deleted, 1);
      expect(h.tokens.token, isNull);
    });

    testWidgets('tapping a booking notification opens the booking', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.push.configured = true;
      final booking = bookingJson();
      h.http.stubs['/bookings/$bookingId'] = {'data': booking};
      await start(tester, h, tokenAccepted: true);
      await tester.pumpAndSettle();

      h.http.respond(200, {'data': notificationJson()});
      h.push.opened.add({
        'notification_id': '01M4JQZ0000000000000000NTF',
        'type': 'booking.confirmed',
        'booking_id': bookingId,
        'audience': 'customer',
      });
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('BK-K2M5XCN4'), findsOneWidget);
      expect(
        h.http.requests.any(
          (r) => r.path == '/notifications/01M4JQZ0000000000000000NTF/read',
        ),
        isTrue,
      );
    });
  });
}
