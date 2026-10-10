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
}
