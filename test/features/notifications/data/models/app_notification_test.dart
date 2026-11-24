import 'package:app/features/auth/data/models/user_role.dart';
import 'package:app/features/notifications/data/models/activity_category.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> notificationJson() => {
    'id': '01M4JQYX4FCJ5B446KS879NKVP',
    'type': 'booking.completed',
    'title': 'Thanks for parking with us',
    'body': 'Booking BK-K2M5XCN4 is complete.',
    'payload': {
      'reference': 'BK-K2M5XCN4',
      'booking_id': '01M4JQYWW2WEFYAASEC49S6PW3',
    },
    'is_read': false,
    'read_at': null,
    'created_at': '2026-10-10T11:07:52Z',
  };

  test('parses and exposes the booking it is about', () {
    final notification = AppNotification.fromJson(notificationJson());

    expect(notification.type, 'booking.completed');
    expect(notification.isRead, isFalse);
    expect(notification.bookingId, '01M4JQYWW2WEFYAASEC49S6PW3');
  });

  test('the audience decides whose view of the booking opens', () {
    AppNotification withPayload(String type, Map<String, Object?> extra) =>
        AppNotification.fromJson({
          ...notificationJson(),
          'type': type,
          'payload': {'booking_id': 'b1', ...extra},
        });

    expect(
      withPayload('booking.confirmed', {'audience': 'owner'}).isForOwner,
      isTrue,
    );
    expect(
      withPayload('booking.confirmed', {'audience': 'customer'}).isForOwner,
      isFalse,
    );
    // Older notifications without an audience: only a request is the owner's.
    expect(withPayload('booking.approval_requested', {}).isForOwner, isTrue);
    expect(withPayload('booking.confirmed', {}).isForOwner, isFalse);
  });

  test('an empty or missing payload is an empty map', () {
    for (final payload in [<Object?>[], null]) {
      final notification = AppNotification.fromJson({
        ...notificationJson(),
        'payload': payload,
      });

      expect(notification.payload, isEmpty, reason: '$payload');
      expect(notification.bookingId, isNull);
    }
  });

  test('keeps a type the app does not know, to show its title and body', () {
    final notification = AppNotification.fromJson({
      ...notificationJson(),
      'type': 'promo.new_city',
    });

    expect(notification.type, 'promo.new_city');
    expect(notification.title, isNotEmpty);
  });

  test(
    'classifies only notification types supported by the mobile contract',
    () {
      AppNotification notice(String type) =>
          AppNotification.fromJson({...notificationJson(), 'type': type});

      expect(
        notice('booking.completed').activityCategory,
        ActivityCategory.bookings,
      );
      expect(
        notice('parking_lot.rejected').activityCategory,
        ActivityCategory.facilities,
      );
      expect(
        notice('payment.refund_completed').activityCategory,
        ActivityCategory.payments,
      );
      expect(
        notice('profile.updated').activityCategory,
        ActivityCategory.account,
      );
      expect(notice('promo.new_city').activityCategory, isNull);
    },
  );

  test(
    'visibility respects notification audience and excludes staff events',
    () {
      AppNotification notice(String type, {String? audience}) =>
          AppNotification.fromJson({
            ...notificationJson(),
            'type': type,
            'payload': {if (audience != null) 'audience': audience},
          });

      expect(
        notice(
          'booking.confirmed',
          audience: 'owner',
        ).isVisibleToRoles([UserRole.customer]),
        isFalse,
      );
      expect(
        notice(
          'booking.confirmed',
          audience: 'owner',
        ).isVisibleToRoles([UserRole.owner]),
        isTrue,
      );
      expect(
        notice(
          'system.worker_failed',
          audience: 'admin',
        ).isVisibleToRoles([UserRole.admin]),
        isFalse,
      );
      expect(
        notice('queue.heartbeat_warning').isVisibleToRoles([UserRole.customer]),
        isFalse,
      );
    },
  );
}
