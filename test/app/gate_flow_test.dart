import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Gate attendants, check-out by code and signed QR passes.
void main() {
  const pass = 'PE1.01M4JQSZSNAVTVCMS8A7AJ0WJ9.29845123.9f2cabc0de';

  Future<void> start(
    WidgetTester tester,
    Harness h, {
    List<String> roles = const ['customer'],
  }) async {
    h.http.respond(200, {'data': userJson(roles: roles)});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> body(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  testWidgets('the customer shows a signed pass that the gate accepts', (
    tester,
  ) async {
    final h = Harness(token: validToken());
    final booking = bookingJson(checkInCode: '7KQ3MZ8D');
    h.http.stubs['/bookings'] = bookingsJson([booking]);
    h.http.stubs['/bookings/$bookingId'] = {'data': booking};
    h.http.stubs['/bookings/$bookingId/check-in-pass'] = {
      'data': {'token': pass, 'expires_at': '2026-11-02T04:20:00Z'},
    };
    await start(tester, h);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BK-K2M5XCN4'));
    await tester.pumpAndSettle();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(find.text('7KQ3 MZ8D'), findsOneWidget);
    expect(
      find.textContaining('The QR code changes every minute'),
      findsOneWidget,
    );
    // The pass, not the code, is what the QR code holds.
    expect(qr.semanticsLabel, isNotNull);
    expect(
      h.http.requests.any((r) => r.path.endsWith('/check-in-pass')),
      isTrue,
    );
  });

  group('attendant', () {
    Future<Harness> atGate(WidgetTester tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/gate/facilities'] = {
        'data': [
          {'id': facilityId, 'name': 'MG Road Metro Parking'},
        ],
      };
      await start(tester, h);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Gate check-in'), findsOneWidget);
      await tester.tap(find.text('Gate check-in'));
      await tester.pumpAndSettle();
      expect(find.text('At MG Road Metro Parking'), findsOneWidget);
      return h;
    }

    testWidgets('checks a car in by typed code, then out', (tester) async {
      final h = await atGate(tester);

      h.http.respond(200, {
        'data': bookingJson(
          spaceLabel: 'B1-07',
          checkedInAt: '2026-11-02T04:35:00Z',
        ),
      });
      await tester.enterText(find.byType(TextField), '7kq3-mz8d');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(writes(h).single.path, '/gate/check-in');
      expect(body(writes(h).single), {'code': '7KQ3MZ8D'});
      expect(find.text('BK-K2M5XCN4 checked in. Bay B1-07.'), findsOneWidget);

      await tester.tap(find.text('Check out').first);
      await tester.pumpAndSettle();
      h.http.respond(200, {'data': bookingJson(status: 'completed')});
      h.scanner.next = pass;
      await tester.tap(find.text('Scan QR code'));
      await tester.pumpAndSettle();

      final out = writes(h).last;
      expect(out.path, '/gate/check-out');
      // A scanned pass is sent exactly as scanned.
      expect(body(out), {'code': pass});
      expect(find.text('BK-K2M5XCN4 checked out.'), findsOneWidget);
    });

    testWidgets('a code from another facility is explained', (tester) async {
      final h = await atGate(tester);

      h.http.respond(404, {
        'error': {'code': 'CHECK_IN_CODE_NOT_FOUND', 'message': 'Not found.'},
      });
      await tester.enterText(find.byType(TextField), 'ZZZZ2222');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No booking at your facilities has this code'),
        findsOneWidget,
      );
    });

    testWidgets('someone without gate access sees no gate', (tester) async {
      final h = Harness(token: validToken());
      await start(tester, h);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Gate check-in'), findsNothing);
    });
  });

  testWidgets('an owner adds and removes a gate attendant', (tester) async {
    final h = Harness(token: validToken());
    const path = '/owner/parking-lots/$facilityId';
    final lot = facilityJson(status: 'approved', withPool: true);
    h.http.stubs['/owner/bookings'] = pageJson(const []);
    h.http.stubs['/owner/parking-lots'] = pageJson([lot['data']]);
    h.http.stubs[path] = lot;
    h.http.stubs['/owner/parking-lot-options'] = optionsJson();
    await start(tester, h, roles: ['customer', 'owner']);
    await tester.tap(find.text('Facilities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();

    final add = find.text('Add attendant');
    await tester.scrollUntilVisible(add, 200);
    await tester.pumpAndSettle();
    expect(find.text('No attendants yet.'), findsOneWidget);
    await tester.tap(add);
    await tester.pumpAndSettle();

    h.http.respond(201, {
      'data': {
        'id': 'att1',
        'name': null,
        'phone_masked': '+91 ******0077',
        'added_at': '2026-11-02T04:00:00Z',
      },
    });
    h.http.stubs['$path/attendants'] = {
      'data': [
        {
          'id': 'att1',
          'name': null,
          'phone_masked': '+91 ******0077',
          'added_at': '2026-11-02T04:00:00Z',
        },
      ],
    };
    await tester.enterText(find.byType(TextField).last, '9800000077');
    final confirm = find.widgetWithText(SecondaryButton, 'Add attendant');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(writes(h).single.path, '$path/attendants');
    expect(body(writes(h).single), {'phone': '+919800000077'});
    expect(find.text('Not signed in yet'), findsOneWidget);
    expect(find.text('+91 ******0077'), findsOneWidget);

    h.http.respond(204, '');
    h.http.stubs['$path/attendants'] = {'data': <Object>[]};
    await tester.ensureVisible(find.text('Remove'));
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(writes(h).last.method, 'DELETE');
    expect(writes(h).last.path, '$path/attendants/att1');
    expect(find.text('No attendants yet.'), findsOneWidget);
  });
}
