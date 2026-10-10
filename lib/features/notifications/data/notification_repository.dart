import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

class NotificationRepository {
  const NotificationRepository(this._api);

  final ApiClient _api;

  /// The signed-in user's notifications, newest first.
  Future<CursorPage<AppNotification>> list({String? cursor}) async =>
      CursorPage.fromJson(
        await _api.get('/notifications', query: {'cursor': cursor}),
        AppNotification.fromJson,
      );

  Future<int> unreadCount() async {
    final count = ApiClient.object(
      await _api.get('/notifications/unread-count'),
    )['unread_count'];
    return count is int ? count : 0;
  }

  Future<AppNotification> markRead(String id) async => AppNotification.fromJson(
    ApiClient.object(await _api.post('/notifications/$id/read')),
  );

  Future<void> markAllRead() => _api.post('/notifications/read-all');
}
