import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
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

  group('activity', () {
    testWidgets('customer profile has no owner-area entry', (tester) async {
      final h = Harness(token: validToken());
      await start(tester, h);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Owner area'), findsNothing);
      expect(find.text('Owner area'), findsNothing);
    });

    testWidgets('shows the unread badge, the list, and opens the booking', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications/unread-count'] = unreadJson(2);
      h.http.stubs['/notifications'] = pageJson([
        notificationJson(),
        notificationJson(id: 'n2', title: 'Booking completed', read: true),
      ]);
      h.http.stubs['/bookings/$bookingId'] = {'data': bookingJson()};
      await start(tester, h);

      expect(find.text('2'), findsOneWidget, reason: 'badge on the tab');

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Booking completed'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      h.http.respond(200, {'data': notificationJson(read: true)});
      h.http.stubs['/notifications/unread-count'] = unreadJson(1);
      await tester.tap(find.text('Booking confirmed'));
      await tester.pumpAndSettle();

      expect(find.text('BK-K2M5XCN4'), findsOneWidget);
      expect(
        h.http.requests.any((r) => r.path == '/notifications/n1/read'),
        isTrue,
      );
      expect(
        h.http.requests.any((r) => r.path == '/bookings/$bookingId'),
        isTrue,
      );
      expect(
        h.http.requests.any((r) => r.path == '/owner/bookings/$bookingId'),
        isFalse,
      );
    });

    testWidgets('opens an owner approval notification in owner bookings', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson([
        notificationJson(type: 'booking.approval_requested'),
      ]);
      h.http.stubs['/owner/bookings/$bookingId'] = {
        'data': bookingJson(status: 'pending_approval'),
      };
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      await start(tester, h, roles: ['customer', 'owner']);
      h.http.respond(200, {'data': notificationJson(read: true)});

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking confirmed'));
      await tester.pumpAndSettle();

      expect(
        h.http.requests.any((r) => r.path == '/owner/bookings/$bookingId'),
        isTrue,
      );
      expect(
        h.http.requests.any((r) => r.path == '/bookings/$bookingId'),
        isFalse,
      );
      expect(find.text('Awaiting approval'), findsOneWidget);
    });

    testWidgets('opens a confirmation sent to the owner in owner bookings', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson([
        notificationJson(audience: 'owner'),
      ]);
      h.http.stubs['/owner/bookings/$bookingId'] = {
        'data': bookingJson(status: 'confirmed'),
      };
      h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
      await start(tester, h, roles: ['customer', 'owner']);
      h.http.respond(200, {'data': notificationJson(read: true)});

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking confirmed'));
      await tester.pumpAndSettle();

      expect(
        h.http.requests.any((r) => r.path == '/owner/bookings/$bookingId'),
        isTrue,
      );
      expect(
        h.http.requests.any((r) => r.path == '/bookings/$bookingId'),
        isFalse,
      );
    });

    testWidgets('says so when there is nothing', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson(const []);
      await start(tester, h);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up."), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('filters activities and excludes staff monitoring notices', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson([
        notificationJson(title: 'Booking confirmed'),
        notificationJson(
          id: 'other',
          type: 'promo.new_city',
          title: 'A new area is available',
        ),
        notificationJson(
          id: 'facility',
          type: 'parking_lot.rejected',
          title: 'Facility review',
          audience: 'owner',
        ),
        notificationJson(
          id: 'payment',
          type: 'payment.refund_completed',
          title: 'Refund processed',
        ),
        notificationJson(
          id: 'account',
          type: 'profile.updated',
          title: 'Profile updated',
        ),
        notificationJson(
          id: 'system',
          type: 'queue.heartbeat_warning',
          title: 'Queue warning',
        ),
        notificationJson(
          id: 'admin',
          type: 'system.worker_failed',
          title: 'Worker failure',
          audience: 'admin',
        ),
      ]);
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('A new area is available'), findsOneWidget);
      expect(find.text('Queue warning'), findsNothing);
      expect(find.text('Worker failure'), findsNothing);

      await tester.tap(find.text('Payments'));
      await tester.pumpAndSettle();
      expect(find.text('Refund processed'), findsOneWidget);
      expect(find.text('Booking confirmed'), findsNothing);
      expect(find.text('A new area is available'), findsNothing);

      await tester.tap(find.text('Facilities').first);
      await tester.pumpAndSettle();
      expect(find.text('Facility review'), findsOneWidget);
      expect(find.text('Refund processed'), findsNothing);

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Profile updated'), findsOneWidget);
      expect(find.text('Facility review'), findsNothing);

      await tester.tap(find.text('Bookings').first);
      await tester.pumpAndSettle();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Refund processed'), findsNothing);
    });

    testWidgets('does not show owner-audience notifications to customers', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson([
        notificationJson(
          type: 'booking.approval_requested',
          title: 'New booking received',
          audience: 'owner',
        ),
        notificationJson(
          id: 'customer',
          title: 'Booking confirmed',
          audience: 'customer',
        ),
      ]);
      await start(tester, h);
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('New booking received'), findsNothing);
      expect(find.text('Booking confirmed'), findsOneWidget);
    });

    testWidgets('shows the category-specific empty state', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson(const []);
      await start(tester, h);
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facilities').first);
      await tester.pumpAndSettle();

      expect(find.text('No facility updates yet.'), findsOneWidget);
    });
  });

  group('owner area', () {
    const path = '/owner/bookings/$bookingId';

    testWidgets('opens on all bookings, including ones awaiting payment', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/owner/bookings'] = pageJson([
        bookingJson(
          status: 'awaiting_payment',
          paymentMode: 'online',
          paymentDeadline: '2026-11-02T04:27:00Z',
        ),
      ]);
      await start(tester, h, roles: ['customer', 'owner']);

      expect(find.text('Payment pending'), findsOneWidget);
      expect(
        h.http.requests
            .lastWhere((request) => request.path == '/owner/bookings')
            .uri
            .queryParameters
            .containsKey('filter[status]'),
        isFalse,
      );
    });

    testWidgets('owner profile has no duplicate Bookings shortcut', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/owner/bookings'] = pageJson(const []);
      h.http.stubs['/owner/parking-lots'] = pageJson(const []);
      h.http.stubs['/owner/earnings'] = earningsJson();
      h.http.stubs['/notifications/unread-count'] = unreadJson(0);
      h.http.stubs['/notifications'] = pageJson(const []);
      await start(tester, h, roles: ['customer', 'owner']);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Owner area'), findsNothing);
      expect(find.text('List your parking and manage bookings.'), findsNothing);

      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      expect(find.text('Bookings'), findsWidgets);

      await tester.tap(find.text('Facilities'));
      await tester.pumpAndSettle();
      expect(find.text('Facilities'), findsWidgets);

      await tester.tap(find.text('Earnings'));
      await tester.pumpAndSettle();
      expect(find.text('Earnings'), findsWidgets);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.text("You're all caught up."), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Owner area'), findsNothing);
    });

    testWidgets(
      'someone who has not applied sees the form, then "under review"',
      (tester) async {
        final h = Harness(token: validToken());
        h.tokens.registrationIntent = 'owner';
        h.http.respond(200, {'data': userJson()});
        h.http.respond(404, {
          'error': {'code': 'OWNER_PROFILE_NOT_FOUND', 'message': 'None.'},
        });
        await tester.pumpWidget(
          ProviderScope(overrides: h.overrides, child: const App()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Become an owner'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(PrimaryButton, 'Send application'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Enter your business name.'), findsOneWidget);

        h.http.respond(201, ownerJson(status: 'pending'));
        await tester.enterText(find.byType(TextField).first, 'Ravi Parking');
        await tester.tap(
          find.widgetWithText(PrimaryButton, 'Send application'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Application under review'), findsOneWidget);
        expect(find.text('Open owner area'), findsNothing);
        expect(h.tokens.registrationIntent, 'owner');
      },
    );

    testWidgets(
      'an owner answers a request, checks in, records payment and checks out',
      (tester) async {
        final h = Harness(token: validToken());
        final request = bookingJson(status: 'pending_approval');
        h.http.stubs['/owner/bookings'] = pageJson([request]);
        h.http.stubs[path] = {'data': request};
        h.http.stubs['$path/collection'] = collectionJson();
        await start(tester, h, roles: ['customer', 'owner']);

        // The owner's own tabs include legacy requests that still need an answer.
        expect(find.text('Facilities'), findsOneWidget);
        expect(find.text('Earnings'), findsOneWidget);
        expect(find.text('Requests'), findsOneWidget);
        expect(find.text('Awaiting approval'), findsOneWidget);

        await tester.tap(find.text('BK-K2M5XCN4'));
        await tester.pumpAndSettle();
        expect(find.text('Pays at the facility'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('Reject request'),
          find.byType(ListView).last,
          const Offset(0, -200),
        );
        expect(find.text('Reject request'), findsOneWidget);
        // Back to the top, where the status is.
        await tester.drag(find.byType(ListView).last, const Offset(0, 600));
        await tester.pumpAndSettle();

        Future<void> act(String button, Map<String, dynamic> after) async {
          h.http.respond(200, {'data': after});
          h.http.stubs[path] = {'data': after};
          await tester.tap(find.widgetWithText(PrimaryButton, button));
          await tester.pumpAndSettle();
        }

        await act('Approve request', bookingJson());
        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('₹80.00 to collect at the facility'), findsOneWidget);

        await act('Check in', bookingJson(checkedInAt: '2026-11-02T04:25:00Z'));
        expect(find.text('Parked'), findsOneWidget);
        expect(find.text('Checked in at 9:55 AM'), findsOneWidget);

        // Recording money asks first and names the amount.
        await tester.dragUntilVisible(
          find.text('Record ₹80.00 received'),
          find.byType(ListView).last,
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record ₹80.00 received'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Confirm the customer paid ₹80.00'),
          findsOneWidget,
        );
        h.http.respond(201, {'data': <String, Object?>{}});
        h.http.stubs['$path/collection'] = collectionJson(collected: true);
        await tester.tap(find.widgetWithText(PrimaryButton, 'Record payment'));
        await tester.pumpAndSettle();
        expect(find.text('₹80.00 collected at the facility'), findsOneWidget);
        expect(find.text('Record ₹80.00 received'), findsNothing);

        // Check out asks first too.
        final done = bookingJson(
          status: 'completed',
          checkedInAt: '2026-11-02T04:25:00Z',
        );
        await tester.tap(find.widgetWithText(PrimaryButton, 'Check out'));
        await tester.pumpAndSettle();
        expect(find.text('Check this vehicle out?'), findsOneWidget);
        h.http.respond(200, {'data': done});
        h.http.stubs[path] = {'data': done};
        await tester.tap(find.widgetWithText(PrimaryButton, 'Check out').last);
        await tester.pumpAndSettle();

        expect(find.text('Completed'), findsOneWidget);
        expect(find.widgetWithText(PrimaryButton, 'Check out'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'earnings show what the API reports, and facilities their review state',
      (tester) async {
        final h = Harness(token: validToken());
        h.http.stubs['/owner/bookings'] = pageJson(const []);
        h.http.stubs['/owner/earnings'] = earningsJson();
        h.http.stubs['/owner/earnings/entries'] = pageJson([
          {
            'id': 'e1',
            'booking_id': bookingId,
            'kind': 'owed_onsite',
            'base_amount': '120.00',
            'commission_rate': '15',
            'commission_amount': '18.00',
            'owner_amount': '102.00',
            'currency': 'INR',
            'created_at': '2026-11-02T04:18:00Z',
          },
        ]);
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
        final lot = lotJson()['data']! as Map<String, dynamic>;
        h.http.stubs['/owner/parking-lots'] = pageJson([
          {
            ...lot,
            'approval_status': 'pending',
            'rejection_reason': null,
            'is_active': false,
            'submitted_at': '2026-10-09T08:00:00Z',
            'reviewed_at': null,
            'created_at': '2026-10-08T08:00:00Z',
            'updated_at': '2026-10-09T08:00:00Z',
          },
        ]);
        await start(tester, h, roles: ['customer', 'owner']);
        expect(find.text('No bookings here'), findsOneWidget);

        await tester.tap(find.text('Earnings'));
        await tester.pumpAndSettle();
        expect(find.text('₹136.00'), findsNWidgets(2));
        expect(find.text('You owe us'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('Commission owed'),
          find.byType(ListView).last,
          const Offset(0, -200),
        );
        expect(find.text('Commission owed'), findsOneWidget);
        expect(find.textContaining('15% commission'), findsOneWidget);
        expect(find.text('Payout in review'), findsOneWidget);
        expect(find.text('₹500.00'), findsOneWidget);

        await tester.tap(find.text('Facilities'));
        await tester.pumpAndSettle();
        expect(find.text('In review'), findsOneWidget);
        expect(find.text('MG Road Metro Parking'), findsOneWidget);
        // Only the add button sits in the bar; no area-switch arrow.
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.swap_horiz_outlined), findsNothing);
        expect(find.textContaining('41 spaces'), findsOneWidget);
      },
    );

    testWidgets('a pending applicant sees status, not owner management tabs', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.tokens.registrationIntent = 'owner';
      h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
      await start(tester, h);

      expect(find.text('Application under review'), findsOneWidget);
      expect(find.text('Requests'), findsNothing);
      expect(find.text('Facilities'), findsNothing);
      expect(find.text('Earnings'), findsNothing);
    });
  });
}
