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
    });

    testWidgets('says so when there is nothing', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/notifications'] = pageJson(const []);
      await start(tester, h);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });
  });

  group('owner area', () {
    const path = '/owner/bookings/$bookingId';

    testWidgets(
      'someone who has not applied sees the form, then "under review"',
      (tester) async {
        final h = Harness(token: validToken());
        await start(tester, h);
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();

        h.http.respond(404, {
          'error': {'code': 'OWNER_PROFILE_NOT_FOUND', 'message': 'None.'},
        });
        await tester.tap(find.text('Owner area'));
        await tester.pumpAndSettle();
        expect(find.text('Become an owner'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(PrimaryButton, 'Send application'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Enter your business name.'), findsOneWidget);

        h.http.respond(201, ownerJson(status: 'pending'));
        await tester.enterText(find.byType(TextField).first, 'Ravi Parking');
        await tester.enterText(find.byType(TextField).last, '9000000002');
        await tester.tap(
          find.widgetWithText(PrimaryButton, 'Send application'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Application under review'), findsOneWidget);
        expect(find.text('Open owner area'), findsNothing);
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

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Owner area'));
        await tester.pumpAndSettle();

        // The owner's own tabs, opening on requests that need an answer.
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
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Owner area'));
        await tester.pumpAndSettle();
        expect(find.text('No requests waiting'), findsOneWidget);

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

        await tester.tap(find.text('Facilities'));
        await tester.pumpAndSettle();
        expect(find.text('In review'), findsOneWidget);
        expect(find.text('MG Road Metro Parking'), findsOneWidget);
        expect(find.textContaining('41 spaces'), findsOneWidget);
      },
    );

    testWidgets('an account that is not an approved owner is told so', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      h.http.respond(403, {
        'error': {'code': 'OWNER_NOT_VERIFIED', 'message': 'Not verified.'},
      });
      await tester.tap(find.text('Owner area'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Your owner account isn't approved yet"),
        findsOneWidget,
      );
    });
  });
}
