import 'package:app/core/api/api_client.dart';
import 'package:app/core/auth/auth_events.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The environment. Overridden in `main` with the values read at start-up,
/// and in tests with a fixed configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('appConfigProvider was not overridden.'),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final authEventsProvider = Provider<AuthEvents>((ref) {
  final events = AuthEvents();
  ref.onDispose(events.dispose);
  return events;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio();
  ref.onDispose(dio.close);

  return ApiClient(
    dio: dio,
    tokenStore: ref.watch(tokenStoreProvider),
    authEvents: ref.watch(authEventsProvider),
    config: ref.watch(appConfigProvider),
    platform: defaultTargetPlatform.name,
  );
});

/// The current time. Overridden in tests; nothing calls `DateTime.now()`
/// directly where the result affects behaviour.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
