import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/state/cursor_list.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:app/features/notifications/state/notifications_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// Also the tests of the shared cursor-list logic, through its first user.
void main() {
  late Harness harness;
  late ProviderContainer container;

  CursorListState<AppNotification> state() =>
      container.read(notificationsProvider);
  NotificationsNotifier notifier() =>
      container.read(notificationsProvider.notifier);

  setUp(() {
    harness = Harness();
    harness.http.stubs.remove('/notifications/unread-count');
    container = harness.container();
    addTearDown(container.dispose);
  });

  Future<void> open(Map<String, dynamic> firstPage) async {
    harness.http.stubs['/notifications/unread-count'] = unreadJson(2);
    harness.http.respond(200, firstPage);
    container.listen(notificationsProvider, (_, _) {});
    await harness.http.idle();
  }

  test('starts loading, then shows the first page', () async {
    final initial = container.read(notificationsProvider);
    expect(initial.isLoading, isTrue);
    await open(pageJson([notificationJson()], nextCursor: 'c2'));

    expect(state().isLoading, isFalse);
    expect(state().items.single.title, 'Booking confirmed');
    expect(state().hasMore, isTrue);
  });

  test('appends the next page and stops at the end', () async {
    await open(pageJson([notificationJson()], nextCursor: 'c2'));
    harness.http.respond(200, pageJson([notificationJson(id: 'n2')]));

    await notifier().loadMore();

    final listRequests = harness.http.requests.where(
      (r) => r.path == '/notifications',
    );
    expect(listRequests.last.uri.queryParameters['cursor'], 'c2');
    expect(state().items.map((n) => n.id), ['n1', 'n2']);
    expect(state().hasMore, isFalse);

    await notifier().loadMore();
    expect(
      harness.http.requests.where((r) => r.path == '/notifications'),
      hasLength(2),
    );
  });

  test('empty is empty; a failed first load is an error', () async {
    await open(pageJson(const []));
    expect(state().isEmpty, isTrue);

    harness.http.fail(DioExceptionType.connectionError);
    container.invalidate(notificationsProvider);
    container.listen(notificationsProvider, (_, _) {});
    await harness.http.idle();

    expect(state().failure?.code, ApiErrorCode.network);
    expect(state().isEmpty, isFalse);
  });

  test('a failed next page, or refresh, keeps what is shown', () async {
    await open(pageJson([notificationJson()], nextCursor: 'c2'));

    harness.http.fail(DioExceptionType.receiveTimeout);
    await notifier().loadMore();
    expect(state().items, hasLength(1));
    expect(state().loadMoreFailure?.code, ApiErrorCode.timeout);
    expect(state().hasMore, isTrue);

    harness.http.fail(DioExceptionType.connectionError);
    await notifier().load();
    expect(state().items, hasLength(1));
    expect(state().failure, isNull);
  });

  test('marking one read changes it at once and tells the API', () async {
    await open(pageJson([notificationJson(), notificationJson(id: 'n2')]));
    harness.http.respond(200, {'data': notificationJson(read: true)});

    await notifier().markRead(state().items.first);

    expect(state().items.map((n) => n.isRead), [true, false]);
    expect(
      harness.http.requests.any(
        (r) => r.method == 'POST' && r.path == '/notifications/n1/read',
      ),
      isTrue,
    );
  });

  test('marking an already-read notification sends nothing', () async {
    await open(pageJson([notificationJson(read: true)]));
    final before = harness.http.requests.length;

    await notifier().markRead(state().items.single);

    expect(harness.http.requests, hasLength(before));
  });

  test('mark all read marks everything shown', () async {
    await open(pageJson([notificationJson(), notificationJson(id: 'n2')]));
    harness.http.respond(200, {
      'data': {'marked': 2},
    });

    await notifier().markAllRead();

    expect(state().items.every((n) => n.isRead), isTrue);
    expect(
      harness.http.requests.any((r) => r.path == '/notifications/read-all'),
      isTrue,
    );
  });

  test(
    'the unread count is zero, not an error, when it cannot be fetched',
    () async {
      harness.http.fail(DioExceptionType.connectionError);

      expect(await container.read(unreadCountProvider.future), 0);
    },
  );
}
