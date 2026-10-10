import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/idempotency_key.dart';
import 'package:app/core/auth/auth_events.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter http;
  late InMemoryTokenStore tokens;
  late AuthEvents events;
  late ApiClient client;

  setUp(() {
    http = FakeHttpAdapter();
    tokens = InMemoryTokenStore();
    events = AuthEvents();
    client = ApiClient(
      dio: Dio()..httpClientAdapter = http,
      tokenStore: tokens,
      authEvents: events,
      config: testConfig,
      platform: 'android',
      clock: () => DateTime.utc(2026, 11, 2),
    );
  });

  tearDown(() => events.dispose());

  Future<ApiException> failure(Future<Object?> call) async {
    try {
      await call;
    } on ApiException catch (exception) {
      return exception;
    }
    fail('Expected an ApiException.');
  }

  group('requests', () {
    test('go to the versioned base with the standard headers', () async {
      http.respond(200, {'data': <String, Object?>{}});

      await client.get('/me');

      expect(http.last.uri.toString(), 'http://api.test/api/v1/me');
      expect(http.last.headers['accept'], 'application/json');
      expect(http.last.headers['X-App-Version'], '1.2.3');
      expect(http.last.headers['X-App-Platform'], 'android');
      expect(http.last.headers.containsKey('authorization'), isFalse);
    });

    test('carry the token when signed in', () async {
      tokens.token = validToken('abc');
      http.respond(200, {'data': <String, Object?>{}});

      await client.get('/me');

      expect(http.last.headers['authorization'], 'Bearer abc');
    });

    test('do not send a token that has already expired', () async {
      tokens.token = StoredToken(
        value: 'old',
        expiresAt: DateTime.utc(2026, 11, 1),
      );
      http.respond(200, {'data': <String, Object?>{}});

      await client.get('/parking-lots');

      expect(http.last.headers.containsKey('authorization'), isFalse);
    });

    test('send a JSON body and the idempotency key', () async {
      http.respond(201, {
        'data': {'id': 'b1'},
      });

      final envelope = await client.post(
        '/bookings',
        body: {'vehicle_type': 'car'},
        idempotencyKey: 'key-1',
      );

      expect(http.last.method, 'POST');
      expect(http.lastBody, {'vehicle_type': 'car'});
      expect(http.last.headers['Idempotency-Key'], 'key-1');
      expect(ApiClient.object(envelope), {'id': 'b1'});
    });

    test('leave null query values out', () async {
      http.respond(200, {'data': <Object?>[]});

      await client.get('/bookings', query: {'cursor': null, 'per_page': 20});

      expect(http.last.uri.queryParameters, {'per_page': '20'});
    });
  });

  group('failures', () {
    test('an error envelope becomes an ApiException with its code', () async {
      http.respond(409, {
        'error': {
          'code': 'SLOT_UNAVAILABLE',
          'message': 'No space is left.',
          'request_id': 'req-1',
        },
      });

      final exception = await failure(client.post('/bookings', body: {}));

      expect(exception.code, ApiErrorCode.slotUnavailable);
      expect(exception.status, 409);
      expect(exception.requestId, 'req-1');
    });

    test('rate limiting carries the wait from Retry-After', () async {
      http.respond(
        429,
        {
          'error': {'code': 'RATE_LIMITED', 'message': 'Slow down.'},
        },
        headers: {'retry-after': '42'},
      );

      final exception = await failure(client.get('/me'));

      expect(exception.code, ApiErrorCode.rateLimited);
      expect(exception.retryAfter, const Duration(seconds: 42));
    });

    test('a non-JSON error page is an unknown failure, not a crash', () async {
      http.respond(502, '<html>Bad gateway</html>');

      final exception = await failure(client.get('/me'));

      expect(exception.code, ApiErrorCode.unknown);
      expect(exception.status, 502);
    });

    test('timeouts and lost connections have their own codes', () async {
      http.fail(DioExceptionType.receiveTimeout);
      expect((await failure(client.get('/me'))).code, ApiErrorCode.timeout);

      http.fail(DioExceptionType.connectionError);
      expect((await failure(client.get('/me'))).code, ApiErrorCode.network);
    });

    test('a refused token is reported once to the session', () async {
      tokens.token = validToken();
      var reports = 0;
      final subscription = events.unauthenticated.listen((_) => reports++);
      http.respond(401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Sign in.'},
      });

      final exception = await failure(client.get('/me'));
      await Future<void>.delayed(Duration.zero);

      expect(exception.code, ApiErrorCode.unauthenticated);
      expect(reports, 1);
      await subscription.cancel();
    });

    test('a 401 while signed out is not a session expiry', () async {
      var reports = 0;
      final subscription = events.unauthenticated.listen((_) => reports++);
      http.respond(401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Sign in.'},
      });

      await failure(client.get('/me'));
      await Future<void>.delayed(Duration.zero);

      expect(reports, 0);
      await subscription.cancel();
    });
  });

  test('object() refuses an envelope without a data object', () {
    expect(
      () => ApiClient.object({'data': <Object?>[]}),
      throwsA(isA<ApiException>()),
    );
  });

  test('idempotency keys are distinct version-4 UUIDs', () {
    final keys = {for (var i = 0; i < 200; i++) newIdempotencyKey()};

    expect(keys, hasLength(200));
    expect(
      keys.every(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch,
      ),
      isTrue,
    );
  });
}
