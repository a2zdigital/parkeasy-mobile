import 'dart:async';

import 'package:app/app/router.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/push/push_messaging.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/notifications/data/models/app_notification.dart';
import 'package:app/features/notifications/data/notification_repository.dart';
import 'package:app/features/notifications/state/notifications_notifier.dart';
import 'package:app/features/notifications/ui/notification_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final registration = PushRegistration(ref);
  ref.onDispose(registration.dispose);
  return registration;
});

/// Keeps the API told which device to push to (`PUT /me/push-token`) for
/// as long as someone is signed in, and opens the right screen when a
/// notification is tapped. Does nothing when push is not configured.
class PushRegistration {
  PushRegistration(this._ref);

  final Ref _ref;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  ProviderSubscription<SessionState>? _session;
  String? _registeredToken;
  bool _listening = false;

  PushMessaging get _messaging => _ref.read(pushMessagingProvider);

  /// Called once at start-up. Registers on every sign-in.
  void start() {
    final beforeSignOut = _ref.read(beforeSignOutProvider);
    if (!beforeSignOut.contains(unregister)) beforeSignOut.add(unregister);
    _session ??= _ref.listen<SessionState>(sessionControllerProvider, (
      previous,
      next,
    ) {
      if (next is SignedIn && previous is! SignedIn) unawaited(_register());
    }, fireImmediately: true);
  }

  Future<void> _register() async {
    if (!await _messaging.start()) return;
    _listen();
    if (!await _messaging.requestPermission()) return;
    final token = await _messaging.token();
    if (token != null) await _send(token);
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _subscriptions
      ..add(
        _messaging.tokenRefreshes.listen((token) => unawaited(_send(token))),
      )
      ..add(_messaging.openedMessages.listen(_open))
      // The Activity badge may be stale now.
      ..add(
        _messaging.foregroundMessages.listen(
          (_) => _ref.invalidate(unreadCountProvider),
        ),
      );
    unawaited(
      _messaging.launchMessage().then((data) {
        if (data != null) _open(data);
      }),
    );
  }

  Future<void> _send(String token) async {
    if (_ref.read(sessionControllerProvider) is! SignedIn) return;
    try {
      await _ref
          .read(apiClientProvider)
          .put(
            '/me/push-token',
            body: {
              'token': token,
              'platform': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android',
            },
          );
      _registeredToken = token;
    } on ApiException catch (failure) {
      // Tried again at the next sign-in or token refresh.
      debugPrint('Push token not registered: ${failure.code}');
    }
  }

  /// Before signing out: this device should no longer get the user's
  /// notifications. Best-effort; signing out never waits on it for long.
  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _ref
          .read(apiClientProvider)
          .delete('/me/push-token', body: {'token': token})
          .timeout(const Duration(seconds: 3));
    } on Object catch (error) {
      debugPrint('Push token not removed: $error');
    }
    await _messaging.deleteToken();
  }

  void _open(PushData data) {
    final id = data['notification_id'];
    final type = data['type'];
    if (id == null || type == null) return;
    final notification = AppNotification(
      id: id,
      type: type,
      title: '',
      body: '',
      payload: Map<String, dynamic>.from(data),
      createdAt: _ref.read(clockProvider)().toUtc(),
    );
    unawaited(_markRead(id));

    final destination = notificationDestination(notification);
    final router = _ref.read(routerProvider);
    if (destination == null) return;
    if (destination.isTab) {
      router.go(destination.route);
    } else {
      router.push(destination.route);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _ref.read(notificationRepositoryProvider).markRead(id);
    } on ApiException {
      // Shows as unread until the next load; nothing else depends on it.
    }
    _ref.invalidate(unreadCountProvider);
  }

  void dispose() {
    _session?.close();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
