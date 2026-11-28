import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/owner/ui/pool_spaces_screen.dart';
import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Gate check-in by code and numbered bays, through the real router.
void main() {
  const poolId = '01M4JQSZT0000000000000POOL';
  const spaceA1 = '01M4JQSZT0000000000000SPA1';

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

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  Map<String, dynamic> body(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.descendant(
      of: find.bySemanticsLabel(label),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  group('customer', () {
    testWidgets('a confirmed booking shows its bay and gate code', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      final booking = bookingJson(spaceLabel: 'B1-07', checkInCode: '7KQ3MZ8D');
      h.http.stubs['/bookings'] = bookingsJson([booking]);
      h.http.stubs['/bookings/$bookingId'] = {'data': booking};
      await start(tester, h);

      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BK-K2M5XCN4'));
      await tester.pumpAndSettle();

      expect(find.text('Bay B1-07'), findsOneWidget);
      expect(find.text('Check-in code'), findsOneWidget);
      expect(find.text('7KQ3 MZ8D'), findsOneWidget);
      // The banner points at the code, not the reference.
      expect(
        find.text("You're booked. Show your check-in code at the entrance."),
        findsOneWidget,
      );
    });

    testWidgets('no code is shown once there is none to show', (tester) async {
      final h = Harness(token: validToken());
      final booking = bookingJson(checkedInAt: '2026-11-02T04:35:00Z');
      h.http.stubs['/bookings'] = bookingsJson([booking]);
      h.http.stubs['/bookings/$bookingId'] = {'data': booking};
      await start(tester, h);

      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BK-K2M5XCN4'));
      await tester.pumpAndSettle();

      expect(find.text('Check-in code'), findsNothing);
      expect(find.textContaining('Bay '), findsNothing);
    });
  });

  group('owner gate check-in', () {
    /// Opens a confirmed booking, then its "Check in with a code".
    Future<Harness> atCheckIn(WidgetTester tester) async {
      final h = Harness(token: validToken());
      final confirmed = bookingJson();
      h.http.stubs['/owner/bookings'] = pageJson([confirmed]);
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': confirmed};
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      await start(tester, h, roles: ['customer', 'owner']);
      // The main Bookings list has no check-in button of its own.
      expect(find.text('Check in with a code'), findsNothing);

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
      expect(find.text("Customer's check-in code"), findsOneWidget);
      return h;
    }

    for (final (label, booking) in [
      ('awaiting approval', bookingJson(status: 'pending_approval')),
      ('checked in', bookingJson(checkedInAt: '2026-11-02T04:35:00Z')),
      ('completed', bookingJson(status: 'completed')),
      ('cancelled', bookingJson(status: 'cancelled')),
    ]) {
      testWidgets('no code check-in on a booking that is $label', (
        tester,
      ) async {
        final h = Harness(token: validToken());
        h.http.stubs['/owner/bookings'] = pageJson([booking]);
        h.http.stubs['/owner/bookings/$bookingId'] = {'data': booking};
        h.http.stubs['/owner/bookings/$bookingId/collection'] =
            collectionJson();
        await start(tester, h, roles: ['customer', 'owner']);
        await tester.tap(find.text('BK-K2M5XCN4'));
        await tester.pumpAndSettle();

        expect(find.text('BK-K2M5XCN4'), findsOneWidget);
        expect(find.text('Check in with a code'), findsNothing);
      });
    }

    testWidgets("another booking's code opens that booking", (tester) async {
      final h = await atCheckIn(tester);
      const otherId = '01M4JQYWW2WEFYAASEC49S6PW4';
      final other = bookingJson(
        id: otherId,
        reference: 'BK-OTHER123',
        checkedInAt: '2026-11-02T04:35:00Z',
      );
      h.http.stubs['/owner/bookings/$otherId'] = {'data': other};
      h.http.stubs['/owner/bookings/$otherId/collection'] = collectionJson();
      h.http.respond(200, {'data': other});
      await fill(tester, "Customer's check-in code", 'AAAA BBBB');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(find.text('BK-OTHER123'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('checks in by the typed code and opens the booking', (
      tester,
    ) async {
      final h = await atCheckIn(tester);

      // Nothing typed: says what is needed and sends nothing.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the code the customer shows.'), findsOneWidget);
      expect(writes(h), isEmpty);

      final checkedIn = bookingJson(
        checkedInAt: '2026-11-02T04:35:00Z',
        spaceLabel: 'B1-07',
      );
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': checkedIn};
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      h.http.respond(200, {'data': checkedIn});
      await fill(tester, "Customer's check-in code", '7kq3-mz8d');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      final sent = writes(h).single;
      expect(sent.path, '/owner/check-in');
      expect(body(sent), {'code': '7KQ3MZ8D'});
      // Back on the same booking, now checked in.
      expect(find.text('BK-K2M5XCN4'), findsOneWidget);
      expect(find.text('Bay B1-07'), findsOneWidget);
      expect(find.text('Check in with a code'), findsNothing);
      expect(find.text("Customer's check-in code"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown code is explained and nothing changes', (
      tester,
    ) async {
      final h = await atCheckIn(tester);
      h.http.respond(404, {
        'error': {'code': 'CHECK_IN_CODE_NOT_FOUND', 'message': 'No.'},
      });
      await fill(tester, "Customer's check-in code", 'ZZZZZZZZ');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No booking at your facilities has this code'),
        findsOneWidget,
      );
      expect(find.text("Customer's check-in code"), findsOneWidget);
    });

    for (final (reason, apiMessage, shown) in [
      (
        'too early',
        'It is too early to check in this booking.',
        'Check-in opens 30 minutes before the booking starts.',
      ),
      (
        'ended',
        'The booked time has already ended.',
        'This booking has already ended. Check-in is no longer available.',
      ),
      (
        'already checked in',
        'This booking has already been checked in.',
        'This booking has already been checked in.',
      ),
    ]) {
      testWidgets('a code refused as $reason says so', (tester) async {
        final h = await atCheckIn(tester);
        h.http.respond(409, {
          'error': {'code': 'CHECK_IN_NOT_ALLOWED', 'message': apiMessage},
        });
        await fill(tester, "Customer's check-in code", 'AAAABBBB');
        await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
        await tester.pumpAndSettle();

        expect(find.text(shown), findsOneWidget);
        expect(find.textContaining('opens shortly'), findsNothing);
        expect(find.text("Customer's check-in code"), findsOneWidget);
      });
    }

    testWidgets('a code for a booking that is not confirmed says so', (
      tester,
    ) async {
      final h = await atCheckIn(tester);
      h.http.respond(409, {
        'error': {'code': 'INVALID_BOOKING_STATE', 'message': 'No.'},
      });
      await fill(tester, "Customer's check-in code", 'AAAABBBB');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(find.textContaining("it isn't confirmed"), findsOneWidget);
    });

    testWidgets('the Check in button is refused as ended on the booking page', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      final booking = bookingJson();
      h.http.stubs['/owner/bookings'] = pageJson([booking]);
      h.http.stubs['/owner/bookings/$bookingId'] = {'data': booking};
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('BK-K2M5XCN4'));
      await tester.pumpAndSettle();

      h.http.respond(409, {
        'error': {
          'code': 'CHECK_IN_NOT_ALLOWED',
          'message': 'The booked time has already ended.',
        },
      });
      await tester.tap(find.widgetWithText(PrimaryButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This booking has already ended. Check-in is no longer available.',
        ),
        findsOneWidget,
      );
    });
  });

  group('owner bays', () {
    const path = '/owner/parking-lots/$facilityId';

    Map<String, dynamic> facility({required bool numbered, int capacity = 40}) {
      final json = facilityJson(withPool: true);
      final data = Map<String, dynamic>.from(json['data'] as Map);
      final pool =
          Map<String, dynamic>.from((data['pools'] as List).first as Map)
            ..['allocation_mode'] = numbered ? 'numbered' : 'pooled'
            ..['capacity'] = capacity;
      data['pools'] = [pool];
      return {'data': data};
    }

    Future<Harness> atPool(
      WidgetTester tester, {
      required bool numbered,
    }) async {
      final h = Harness(token: validToken());
      final lot = facility(numbered: numbered, capacity: numbered ? 2 : 40);
      h.http.stubs['/owner/bookings'] = pageJson(const []);
      h.http.stubs['/owner/parking-lots'] = pageJson([lot['data']]);
      h.http.stubs[path] = lot;
      h.http.stubs['/owner/parking-lot-options'] = optionsJson();
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Facilities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(numbered ? '2 spaces' : '40 spaces'),
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets(
      'a pooled vehicle type switches to numbered bays from a range',
      (tester) async {
        final h = await atPool(tester, numbered: false);
        expect(find.text('Customers park in any free space.'), findsOneWidget);
        expect(find.text('Number of spaces'), findsOneWidget);

        h.http.stubs['/owner/pools/$poolId/spaces'] = {'data': <Object?>[]};
        await tester.ensureVisible(find.text('Use numbered bays'));
        await tester.tap(find.text('Use numbered bays'));
        await tester.pumpAndSettle();
        expect(find.text('Bays'), findsOneWidget);

        await fill(tester, 'Label start', 'A-');
        await fill(tester, 'From', '01');
        await fill(tester, 'To', '03');
        await fill(tester, 'Or type labels', 'VIP 1');
        h.http.respond(200, facility(numbered: true, capacity: 4));
        h.http.stubs[path] = facility(numbered: true, capacity: 4);
        h.http.stubs['/owner/pools/$poolId/spaces'] = {
          'data': [
            for (final label in ['A-01', 'A-02', 'A-03', 'VIP 1'])
              {'id': 'S-$label', 'label': label, 'is_active': true},
          ],
        };
        await tester.ensureVisible(find.text('Number these spaces'));
        await tester.tap(find.text('Number these spaces'));
        await tester.pumpAndSettle();

        final sent = writes(h).single;
        expect(sent.method, 'PUT');
        expect(sent.path, '/owner/pools/$poolId/allocation-mode');
        expect(body(sent), {
          'allocation_mode': 'numbered',
          'labels': ['A-01', 'A-02', 'A-03', 'VIP 1'],
        });
        expect(find.text('4 of 4 in use'), findsOneWidget);
        expect(find.text('Add bays'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a numbered pool hides capacity and takes bays out of use', (
      tester,
    ) async {
      final h = await atPool(tester, numbered: true);
      expect(find.text('Number of spaces'), findsNothing);
      expect(
        find.text('The number of spaces follows the bays in use.'),
        findsOneWidget,
      );

      h.http.stubs['/owner/pools/$poolId/spaces'] = {
        'data': [
          {'id': spaceA1, 'label': 'A-1', 'is_active': true},
          {'id': 'S2', 'label': 'A-2', 'is_active': true},
        ],
      };
      await tester.ensureVisible(find.text('Manage bays'));
      await tester.tap(find.text('Manage bays'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 in use'), findsOneWidget);

      // A booked bay cannot be taken out of use: the refusal is explained.
      h.http.respond(409, {
        'error': {'code': 'PARKING_SPACE_IN_USE', 'message': 'Booked.'},
      });
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final sent = writes(h).single;
      expect(sent.method, 'PATCH');
      expect(sent.path, '/owner/pools/$poolId/spaces/$spaceA1');
      expect(body(sent), {'is_active': false});
      expect(
        find.text("This bay has bookings, so it can't change now."),
        findsOneWidget,
      );
    });

    testWidgets('invalid bay input is caught before anything is sent', (
      tester,
    ) async {
      final h = await atPool(tester, numbered: false);
      h.http.stubs['/owner/pools/$poolId/spaces'] = {'data': <Object?>[]};
      await tester.ensureVisible(find.text('Use numbered bays'));
      await tester.tap(find.text('Use numbered bays'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Number these spaces'));
      await tester.tap(find.text('Number these spaces'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least one bay.'), findsOneWidget);

      await fill(tester, 'Or type labels', '#1');
      await tester.ensureVisible(find.text('Number these spaces'));
      await tester.tap(find.text('Number these spaces'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Use letters, numbers'), findsOneWidget);
      expect(writes(h), isEmpty);
    });
  });

  group('parseBayInput', () {
    final l10n = AppLocalizationsEn();

    test('a range keeps the width of its first number', () {
      final parsed = parseBayInput(
        l10n,
        prefix: 'B1-',
        from: '08',
        to: '10',
        list: '',
      );
      expect(parsed.labels, ['B1-08', 'B1-09', 'B1-10']);
      expect(parsed.error, isNull);
    });

    test('labels are trimmed and repeated ones dropped, ignoring case', () {
      final parsed = parseBayInput(
        l10n,
        prefix: '',
        from: '',
        to: '',
        list: ' a1, A1 ,b2,, ',
      );
      expect(parsed.labels, ['a1', 'b2']);
    });

    test('a backwards or oversized range is refused', () {
      expect(
        parseBayInput(l10n, prefix: '', from: '5', to: '1', list: '').error,
        l10n.baysRangeInvalid,
      );
      expect(
        parseBayInput(l10n, prefix: '', from: '1', to: '201', list: '').error,
        l10n.baysRangeInvalid,
      );
    });
  });
}
