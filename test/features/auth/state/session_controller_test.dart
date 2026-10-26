import 'dart:async';

import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/models/session.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;

  SessionState state() => container.read(sessionControllerProvider);
  SessionController controller() =>
      container.read(sessionControllerProvider.notifier);

  void start({StoredToken? token}) {
    harness = Harness(token: token);
    container = harness.container();
    addTearDown(container.dispose);
    // Keep the provider alive for the length of the test.
    container.listen(sessionControllerProvider, (_, _) {});
  }

  test('starts unknown', () {
    start();

    expect(state(), isA<SessionUnknown>());
  });

  group('restore', () {
    test('with no token: signed out, and the API is not called', () async {
      start();

      await controller().restore();

      expect(state(), isA<SignedOut>());
      expect(harness.http.requests, isEmpty);
    });

    test('with an expired token: signed out and the token removed', () async {
      start(
        token: StoredToken(value: 'old', expiresAt: DateTime.utc(2026, 11, 1)),
      );

      await controller().restore();

      expect(state(), isA<SignedOut>());
      expect(harness.tokens.token, isNull);
      expect(harness.http.requests, isEmpty);
    });

    test(
      'when secure storage fails: exposes a retryable restore failure',
      () async {
        harness = Harness();
        final tokens = _FailingReadTokenStore();
        container = ProviderContainer(
          overrides: [
            ...harness.overrides,
            tokenStoreProvider.overrideWithValue(tokens),
          ],
        );
        addTearDown(container.dispose);
        container.listen(sessionControllerProvider, (_, _) {});

        await controller().restore();

        expect(
          (state() as SessionRestoreFailed).failure.code,
          ApiErrorCode.unknown,
        );
        expect(harness.http.requests, isEmpty);

        tokens.failRead = false;
        await controller().restore();

        expect(state(), isA<SignedOut>());
      },
    );

    test('with a good token: signed in as the user the API returns', () async {
      start(token: validToken());
      harness.http.respond(200, {'data': userJson()});

      await controller().restore();

      expect((state() as SignedIn).user.name, 'Asha');
      expect(harness.http.last.path, '/me');
    });

    test('when the API refuses the token: signed out, token removed', () async {
      start(token: validToken());
      harness.http.respond(401, errorUnauthenticated);

      await controller().restore();
      await harness.http.idle();

      expect(state(), isA<SignedOut>());
      expect(harness.tokens.token, isNull);
    });

    test(
      'when offline: stays signed in on this device and can retry',
      () async {
        start(token: validToken());
        harness.http.fail(DioExceptionType.connectionError);

        await controller().restore();

        final failed = state() as SessionRestoreFailed;
        expect(failed.failure.code, ApiErrorCode.network);
        expect(harness.tokens.token, isNotNull, reason: 'the token is kept');

        harness.http.respond(200, {'data': userJson()});
        await controller().restore();

        expect(state(), isA<SignedIn>());
      },
    );
  });

  test('start stores the token and signs in', () async {
    start();
    final session = Session.fromJson(
      sessionJson()['data']! as Map<String, dynamic>,
    );

    await controller().start(session);

    expect(harness.tokens.token?.value, '12|secret');
    expect(harness.tokens.token?.expiresAt, DateTime.utc(2027, 1, 8, 10));
    expect(state(), isA<SignedIn>());
  });

  test('updateUser replaces the user only while signed in', () async {
    start();
    final user = User.fromJson(userJson(name: 'New name'));

    controller().updateUser(user);
    expect(state(), isA<SessionUnknown>());

    await controller().start(
      Session.fromJson(sessionJson()['data']! as Map<String, dynamic>),
    );
    controller().updateUser(user);

    expect((state() as SignedIn).user.name, 'New name');
  });

  group('signOut', () {
    test(
      'clears the local session without waiting for server revocation',
      () async {
        start(token: validToken());
        final release = Completer<void>();
        harness.http.respondLater(200, {
          'data': <String, Object?>{},
        }, release: release);

        await controller().signOut();
        await harness.http.waitForRequests(1);

        expect(state(), isA<SignedOut>());
        expect(harness.tokens.token, isNull);
        expect(harness.http.last.path, '/auth/logout');
        expect(harness.http.last.headers.containsKey('authorization'), isTrue);

        release.complete();
        await harness.http.idle();
      },
    );

    test('tells the server, removes the token and signs out', () async {
      start(token: validToken());
      harness.http.respond(200, {'data': <String, Object?>{}});

      await controller().signOut();
      await harness.http.waitForRequests(1);

      expect(harness.http.last.path, '/auth/logout');
      expect(harness.http.last.headers['authorization'], 'Bearer token-1');
      expect(harness.tokens.token, isNull);
      expect(state(), isA<SignedOut>());
    });

    test(
      'still signs out on this device when the server is unreachable',
      () async {
        start(token: validToken());
        harness.http.fail(DioExceptionType.connectionError);

        await controller().signOut();

        expect(harness.tokens.token, isNull);
        expect(state(), isA<SignedOut>());
      },
    );
  });

  test('a refused token anywhere in the app signs the user out', () async {
    start(token: validToken());
    harness.http.respond(200, {'data': userJson()});
    await controller().restore();
    expect(state(), isA<SignedIn>());

    harness.http.respond(401, errorUnauthenticated);
    await expectLater(
      container.read(apiClientProvider).get('/bookings'),
      throwsA(anything),
    );
    await harness.http.idle();

    expect(state(), isA<SignedOut>());
    expect(harness.tokens.token, isNull);
  });
}

class _FailingReadTokenStore extends InMemoryTokenStore {
  bool failRead = true;

  @override
  Future<StoredToken?> read() async {
    if (failRead) {
      throw PlatformException(code: 'secure_storage_failure');
    }
    return super.read();
  }
}
