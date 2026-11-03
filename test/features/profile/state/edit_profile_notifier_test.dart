import 'dart:async';

import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/profile/state/edit_profile_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;

  setUp(() {
    harness = Harness();
    container = harness.container();
    addTearDown(container.dispose);
    container.listen(sessionControllerProvider, (_, _) {});
  });

  group('EditProfileNotifier', () {
    EditProfileState state() => container.read(editProfileProvider);
    EditProfileNotifier notifier() =>
        container.read(editProfileProvider.notifier);

    setUp(() => container.listen(editProfileProvider, (_, _) {}));

    test(
      'validates an empty or invalid name without calling the API',
      () async {
        await notifier().save(
          name: '   ',
          email: '',
          initialName: 'Asha',
          initialEmail: null,
        );
        expect(state().isNameMissing, isTrue);
        expect(state().isNameInvalid, isFalse);
        expect(harness.http.requests, isEmpty);

        notifier().clearProblems();
        expect(state().isNameMissing, isFalse);

        await notifier().save(
          name: 'A',
          email: '',
          initialName: 'Asha',
          initialEmail: null,
        );
        expect(state().isNameMissing, isFalse);
        expect(state().isNameInvalid, isTrue);
        expect(harness.http.requests, isEmpty);
      },
    );

    test(
      'saves trimmed profile fields, updates session and sets didSave',
      () async {
        harness.tokens.token = validToken();
        harness.http.respond(200, {'data': userJson()});
        await container.read(sessionControllerProvider.notifier).restore();

        harness.http.respond(200, {
          'data': userJson(name: 'Asha Rao', email: 'deeptimetri6@gmail.com'),
        });
        await notifier().save(
          name: '  Asha Rao ',
          email: ' deeptimetri6@gmail.com ',
          initialName: 'Asha',
          initialEmail: null,
        );

        expect(harness.http.last.method, 'PATCH');
        expect(harness.http.lastBody, {
          'name': 'Asha Rao',
          'email': 'deeptimetri6@gmail.com',
        });
        expect(state().didSave, isTrue);
        expect(state().isSubmitting, isFalse);

        final session = container.read(sessionControllerProvider) as SignedIn;
        expect(session.user.name, 'Asha Rao');
        expect(session.user.email, 'deeptimetri6@gmail.com');
      },
    );

    test('validates email and allows clearing it', () async {
      await notifier().save(
        name: 'Asha Rao',
        email: 'not-an-email',
        initialName: 'Asha Rao',
        initialEmail: null,
      );
      expect(state().isEmailInvalid, isTrue);
      expect(state().isEmailRejected, isFalse);
      expect(harness.http.requests, isEmpty);

      harness.http.respond(200, {'data': userJson(name: 'Asha Rao')});
      await notifier().save(
        name: 'Asha Rao',
        email: '',
        initialName: 'Asha Rao',
        initialEmail: 'asha@example.test',
      );

      expect(harness.http.lastBody, {'email': null});
      expect(state().didSave, isTrue);
    });

    test('prevents duplicate submissions while save is in progress', () async {
      harness.tokens.token = validToken();
      harness.http.respond(200, {'data': userJson()});
      await container.read(sessionControllerProvider.notifier).restore();

      final releaseResponse = Completer<void>();
      harness.http.respondLater(200, {
        'data': userJson(name: 'Asha Rao'),
      }, release: releaseResponse);

      final firstCall = notifier().save(
        name: 'Asha Rao',
        email: '',
        initialName: 'Asha',
        initialEmail: null,
      );
      expect(state().isSubmitting, isTrue);

      // Second call while submitting
      final secondCall = notifier().save(
        name: 'Another Name',
        email: '',
        initialName: 'Asha',
        initialEmail: null,
      );
      await secondCall;

      releaseResponse.complete();
      await firstCall;

      expect(
        harness.http.requests
            .where(
              (request) => request.method == 'PATCH' && request.path == '/me',
            )
            .length,
        1,
      );
      expect(state().didSave, isTrue);
    });

    test('shows API validation error on the name field', () async {
      harness.http.respond(422, {
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'Invalid.',
          'details': {
            'name': ['The name is unacceptable.'],
          },
        },
      });

      await notifier().save(
        name: 'Bad Name',
        email: '',
        initialName: 'Asha',
        initialEmail: null,
      );

      expect(state().isNameInvalid, isTrue);
      expect(state().failure, isNull);
      expect(state().didSave, isFalse);
    });

    test('shows API validation error on the email field', () async {
      harness.http.respond(422, {
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'Invalid.',
          'details': {
            'email': ['The email is not accepted.'],
          },
        },
      });

      await notifier().save(
        name: 'Asha Rao',
        email: 'asha@example.test',
        initialName: 'Asha',
        initialEmail: null,
      );

      expect(state().isEmailInvalid, isFalse);
      expect(state().isEmailRejected, isTrue);
      expect(state().failure, isNull);
      expect(state().didSave, isFalse);
    });

    test('shows an API failure and does not update session', () async {
      harness.tokens.token = validToken();
      harness.http.respond(200, {'data': userJson()});
      await container.read(sessionControllerProvider.notifier).restore();

      harness.http.respond(503, {
        'error': {
          'code': 'SERVICE_UNAVAILABLE',
          'message': 'Unavailable.',
          'request_id': 'req-123',
        },
      });

      await notifier().save(
        name: 'Asha Rao',
        email: '',
        initialName: 'Asha',
        initialEmail: null,
      );

      expect(state().failure?.code, ApiErrorCode.serviceUnavailable);
      expect(state().didSave, isFalse);

      final session = container.read(sessionControllerProvider) as SignedIn;
      expect(session.user.name, 'Asha');
    });
  });
}
