import 'package:app/app/routes.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';

/// Where tapping a notification leads.
///
/// [isTab] means the route is a whole tab, opened with `go`; anything else
/// is a detail screen pushed on top of the current one.
typedef NotificationDestination = ({String route, bool isTab});

/// The screen a notification opens, or null when it has nowhere to go (its
/// message says everything, or it is meant for the admin panel). Unknown
/// types fall back to the booking they name, if any.
NotificationDestination? notificationDestination(AppNotification notification) {
  final payload = notification.payload;
  String? id(String key) {
    final value = payload[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  // Staff notifications belong to the admin panel.
  if (payload['audience'] == 'admin') return null;

  final lotId = id('parking_lot_id');
  if (lotId != null && notification.type.startsWith('parking_lot.')) {
    return (route: Routes.ownerFacility(lotId), isTab: false);
  }

  final ticketId = id('support_ticket_id');
  if (ticketId != null && notification.type.startsWith('support.')) {
    return (
      route: notification.isForOwner
          ? '${Routes.ownerProfileHelp}/$ticketId'
          : '${Routes.profileHelp}/$ticketId',
      isTab: false,
    );
  }

  if (notification.type.startsWith('payout.')) {
    return (route: Routes.ownerEarnings, isTab: true);
  }

  if (notification.type == 'owner.approved') {
    return (route: Routes.ownerFacilities, isTab: true);
  }

  final bookingId = notification.bookingId;
  if (bookingId != null) {
    return (
      route: notification.isForOwner
          ? Routes.ownerBooking(bookingId)
          : Routes.booking(bookingId),
      isTab: false,
    );
  }

  return null;
}
