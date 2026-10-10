import 'package:app/core/api/api_client.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fakes.dart';

/// The app's dependencies with every edge faked: HTTP, token storage and
/// the clock.
class Harness {
  Harness({StoredToken? token, DateTime? now})
    : http = FakeHttpAdapter(),
      tokens = InMemoryTokenStore(token),
      now = now ?? DateTime.utc(2026, 11, 2, 4);

  final FakeHttpAdapter http;
  final InMemoryTokenStore tokens;
  DateTime now;

  late final List<Override> overrides = [
    appConfigProvider.overrideWithValue(testConfig),
    tokenStoreProvider.overrideWithValue(tokens),
    clockProvider.overrideWithValue(() => now),
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        dio: Dio()..httpClientAdapter = http,
        tokenStore: tokens,
        authEvents: ref.watch(authEventsProvider),
        config: testConfig,
        platform: 'android',
        clock: () => now,
      ),
    ),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}

Map<String, dynamic> userJson({
  String? name = 'Asha',
  bool complete = true,
  List<String> roles = const ['customer'],
}) => {
  'id': '01M4JQSZSNAVTVCMS8A7AJ0USR',
  'name': name,
  'phone': '+919000000001',
  'email': null,
  'status': 'active',
  'roles': roles,
  'is_profile_complete': complete,
  'created_at': '2026-10-10T10:00:00Z',
};

Map<String, dynamic> sessionJson({bool newUser = false}) => {
  'data': {
    'token': '12|secret',
    'token_type': 'Bearer',
    'expires_at': '2027-01-08T10:00:00Z',
    'is_new_user': newUser,
    'user': userJson(name: newUser ? null : 'Asha', complete: !newUser),
  },
};

const errorUnauthenticated = {
  'error': {'code': 'UNAUTHENTICATED', 'message': 'Sign in.'},
};
