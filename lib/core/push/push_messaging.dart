import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The data of a push message: `notification_id`, `type` and the
/// notification's payload, all as strings (FCM data values are strings).
typedef PushData = Map<String, String>;

/// Push notifications through Firebase Cloud Messaging.
///
/// Firebase is configured by files that are not in the repository
/// (`google-services.json`, `GoogleService-Info.plist`). Without them
/// [start] returns false and the app works without push: the in-app
/// Activity list still has every notification.
abstract class PushMessaging {
  /// Connects to Firebase. False when this build has no Firebase
  /// configuration, or it could not start.
  Future<bool> start();

  /// Asks the user to allow notifications. True when allowed.
  Future<bool> requestPermission();

  /// This device's push token, or null when there is none yet.
  Future<String?> token();

  /// Firebase replaced this device's token.
  Stream<String> get tokenRefreshes;

  /// The user tapped a notification while the app was in the background.
  Stream<PushData> get openedMessages;

  /// A message arrived while the app was open.
  Stream<PushData> get foregroundMessages;

  /// The notification that launched the app from closed, if any.
  Future<PushData?> launchMessage();

  /// Forgets this device's token, so the next user gets a new one.
  Future<void> deleteToken();
}

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging(),
);

class FirebasePushMessaging implements PushMessaging {
  bool _started = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> start() async {
    if (_started) return true;
    try {
      // No options: they come from the platform files. A build without
      // those files throws here, and push stays off.
      await Firebase.initializeApp();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      _started = true;
    } on Object catch (error) {
      debugPrint(
        'Push notifications are off: Firebase did not start ($error).',
      );
    }
    return _started;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_started) return false;
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    if (!_started) return null;
    try {
      // The API sends with FCM HTTP v1 registration tokens, which is what
      // getToken returns. Its replacement (register / onRegistered) hands
      // out installation IDs for a different send API.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } on Object catch (error) {
      // iOS without an APNs key in Firebase, or no network.
      debugPrint('No push token: $error');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes =>
      // Registration tokens, as for token() above.
      // ignore: deprecated_member_use
      _started ? _messaging.onTokenRefresh : const Stream.empty();

  @override
  Stream<PushData> get openedMessages => _started
      ? FirebaseMessaging.onMessageOpenedApp.map(_data)
      : const Stream.empty();

  @override
  Stream<PushData> get foregroundMessages =>
      _started ? FirebaseMessaging.onMessage.map(_data) : const Stream.empty();

  @override
  Future<PushData?> launchMessage() async {
    if (!_started) return null;
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _data(message);
  }

  @override
  Future<void> deleteToken() async {
    if (!_started) return;
    try {
      // Pairs with getToken; see token().
      // ignore: deprecated_member_use
      await _messaging.deleteToken();
    } on Object catch (error) {
      debugPrint('Could not delete the push token: $error');
    }
  }

  static PushData _data(RemoteMessage message) => {
    for (final entry in message.data.entries) entry.key: '${entry.value}',
  };
}
