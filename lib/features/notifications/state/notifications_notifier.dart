import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/state/cursor_list.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsProvider =
    NotifierProvider.autoDispose<
      NotificationsNotifier,
      CursorListState<AppNotification>
    >(NotificationsNotifier.new);

/// The number on the Activity tab. A failure to fetch it shows no number;
/// it is never an error the user must deal with.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return await ref.watch(notificationRepositoryProvider).unreadCount();
  } on ApiException {
    return 0;
  }
});

class NotificationsNotifier extends CursorListNotifier<AppNotification> {
  @override
  Future<CursorPage<AppNotification>> fetchPage(String? cursor) {
    // Whenever the list is (re)loaded the badge may be stale too.
    if (cursor == null) ref.invalidate(unreadCountProvider);
    return ref.read(notificationRepositoryProvider).list(cursor: cursor);
  }

  /// Marks one notification read. The list changes at once; if the API
  /// call fails the item simply shows as unread again on the next load.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    replaceItems(
      (items) => [
        for (final item in items)
          item.id == notification.id ? item.copyWith(isRead: true) : item,
      ],
    );
    try {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
    } on ApiException {
      // Not worth interrupting the user for.
    }
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } on ApiException {
      return;
    }
    replaceItems(
      (items) => [for (final item in items) item.copyWith(isRead: true)],
    );
    ref.invalidate(unreadCountProvider);
  }
}
