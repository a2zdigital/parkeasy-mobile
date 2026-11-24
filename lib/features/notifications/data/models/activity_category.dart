import 'package:app/features/auth/data/models/user_role.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';

enum ActivityCategory { bookings, facilities, payments, account }

extension AppNotificationActivityCategory on AppNotification {
  ActivityCategory? get activityCategory => activityCategoryForType(type);
}

ActivityCategory? activityCategoryForType(String type) {
  if (type.startsWith('booking.')) return ActivityCategory.bookings;
  if (type.startsWith('parking_lot.')) return ActivityCategory.facilities;
  if (type.startsWith('payment.') ||
      type.startsWith('refund.') ||
      type.startsWith('commission.') ||
      type.startsWith('payout.')) {
    return ActivityCategory.payments;
  }
  if (type.startsWith('account.') ||
      type.startsWith('profile.') ||
      type.startsWith('security.') ||
      type.startsWith('auth.') ||
      type.startsWith('owner.')) {
    return ActivityCategory.account;
  }
  return null;
}

extension UserActivityVisibility on AppNotification {
  /// Technical events and staff-only messages do not belong in the mobile
  /// Activity list; this app has no admin dashboard.
  bool get isUserActivity {
    if (payload['audience'] == 'admin' || payload['audience'] == 'operations') {
      return false;
    }

    final typeParts = type.toLowerCase().split(RegExp(r'[._-]'));
    const systemTypeParts = {
      'background',
      'heartbeat',
      'health',
      'monitoring',
      'ops',
      'outbox',
      'queue',
      'scheduler',
      'server',
      'system',
      'worker',
    };
    return !typeParts.any(systemTypeParts.contains);
  }

  bool isVisibleToRoles(Iterable<UserRole> roles) {
    if (!isUserActivity) return false;

    final roleSet = roles.toSet();
    return switch (payload['audience']) {
      'owner' => roleSet.contains(UserRole.owner),
      'customer' => roleSet.contains(UserRole.customer),
      _ =>
        type != 'booking.approval_requested' ||
            roleSet.contains(UserRole.owner),
    };
  }
}
