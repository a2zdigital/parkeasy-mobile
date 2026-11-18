import 'package:app/app/routes.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:app/features/notifications/ui/notification_route.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification notice(String type, Map<String, dynamic> payload) =>
    AppNotification(
      id: 'n1',
      type: type,
      title: 'Title',
      body: 'Body',
      payload: payload,
      createdAt: DateTime.utc(2026, 11, 5),
    );

void main() {
  group('notificationDestination', () {
    test('a customer booking notification opens the booking', () {
      expect(
        notificationDestination(
          notice('payment.refund_completed', {
            'booking_id': 'B1',
            'audience': 'customer',
          }),
        ),
        (route: Routes.booking('B1'), isTab: false),
      );
    });

    test('an owner booking notification opens the owner view', () {
      expect(
        notificationDestination(
          notice('booking.confirmed', {
            'booking_id': 'B1',
            'audience': 'owner',
          }),
        ),
        (route: Routes.ownerBooking('B1'), isTab: false),
      );
    });

    test('a facility decision opens the facility', () {
      expect(
        notificationDestination(
          notice('parking_lot.rejected', {
            'parking_lot_id': 'L1',
            'audience': 'owner',
          }),
        ),
        (route: Routes.ownerFacility('L1'), isTab: false),
      );
    });

    test('a payout decision opens the earnings tab', () {
      expect(
        notificationDestination(
          notice('payout.approved', {'payout_id': 'P1', 'audience': 'owner'}),
        ),
        (route: Routes.ownerEarnings, isTab: true),
      );
    });

    test('an approved owner lands on facilities', () {
      expect(
        notificationDestination(
          notice('owner.approved', {'audience': 'owner'}),
        ),
        (route: Routes.ownerFacilities, isTab: true),
      );
    });

    test('staff notifications and self-contained messages go nowhere', () {
      expect(
        notificationDestination(
          notice('admin.refund_failed', {
            'booking_id': 'B1',
            'audience': 'admin',
          }),
        ),
        isNull,
      );
      expect(
        notificationDestination(
          notice('owner.rejected', {'audience': 'owner'}),
        ),
        isNull,
      );
    });
  });
}
