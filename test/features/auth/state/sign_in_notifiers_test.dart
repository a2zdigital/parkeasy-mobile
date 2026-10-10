import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/auth/state/otp_notifier.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/profile/state/complete_profile_notifier.dart';
import 'package:dio/dio.dart';
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

  group('PhoneNumber', () {
    test('accepts ten digits, with or without spaces and country code', () {
      for (final input in ['9000000001', '90000 00001', '+919000000001']) {
        expect(PhoneNumber.toE164(input), '+919000000001', reason: input);
      }
    });

    test('rejects numbers that cannot be Indian mobiles', () {
      for (final input in ['', '12345', '5000000001', '90000000011', 'abc']) {
        expect(PhoneNumber.toE164(input), isNull, reason: input);
      }
    });

    test('formats for display', () {
      expect(PhoneNumber.format('+919000000001'), '+91 90000 00001');
      expect(PhoneNumber.format('+15550100'), '+15550100');
    });
  });

  group('PhoneSignInNotifier', () {
    PhoneSignInState state() => container.read(phoneSignInProvider);
    PhoneSignInNotifier notifier() =>
        container.read(phoneSignInProvider.notifier);

    setUp(() => container.listen(phoneSignInProvider, (_, _) {}));

    test('an invalid number is caught before calling the API', () async {
      await notifier().submit('12345');

      expect(state().isPhoneInvalid, isTrue);
      expect(harness.http.requests, isEmpty);
    });

    test(
      'sends the E.164 number and records when a resend is allowed',
      () async {
        harness.http.respond(200, {
          'data': {'expires_in': 300, 'resend_in': 30},
        });

        await notifier().submit('90000 00001');

        expect(harness.http.lastBody, {'phone': '+919000000001'});
        expect(state().sent?.phone, '+919000000001');
        expect(
          state().sent?.resendAt,
          harness.now.add(const Duration(seconds: 30)),
        );
        expect(state().isSubmitting, isFalse);
      },
    );

    test(
      'a failure is kept for the screen to explain, and can be retried',
      () async {
        harness.http.fail(DioExceptionType.connectionError);
        await notifier().submit('9000000001');
        expect(state().failure?.code, ApiErrorCode.network);

        harness.http.respond(200, {
          'data': {'expires_in': 300, 'resend_in': 30},
        });
        await notifier().submit('9000000001');

        expect(state().failure, isNull);
        expect(state().sent, isNotNull);
      },
    );

    test('editing the field clears the last problem', () async {
      await notifier().submit('1');
      notifier().clearProblems();

      expect(state().isPhoneInvalid, isFalse);
    });
  });

  group('OtpNotifier', () {
    late CodeSent sent;
    OtpState state() => container.read(otpProvider(sent));
    OtpNotifier notifier() => container.read(otpProvider(sent).notifier);

    setUp(() {
      sent = CodeSent(
        phone: '+919000000001',
        resendAt: harness.now.add(const Duration(seconds: 30)),
      );
      container.listen(otpProvider(sent), (_, _) {});
    });

    test('a short code is caught before calling the API', () async {
      await notifier().verify('123');

      expect(state().isIncomplete, isTrue);
      expect(harness.http.requests, isEmpty);
    });

    test('a correct code signs the user in and stores the token', () async {
      harness.http.respond(200, sessionJson());

      await notifier().verify('123456');

      expect(harness.http.lastBody, {
        'phone': '+919000000001',
        'code': '123456',
        'device_name': isNotEmpty,
      });
      expect(container.read(sessionControllerProvider), isA<SignedIn>());
      expect(harness.tokens.token?.value, '12|secret');
    });

    test('a wrong code leaves the user signed out with the reason', () async {
      harness.http.respond(422, {
        'error': {'code': 'OTP_INVALID', 'message': 'Wrong code.'},
      });

      await notifier().verify('000000');

      expect(state().failure?.code, ApiErrorCode.otpInvalid);
      expect(state().isVerifying, isFalse);
      expect(container.read(sessionControllerProvider), isNot(isA<SignedIn>()));
      expect(harness.tokens.token, isNull);
    });

    test(
      'a resend is refused until the wait is over, then moves the wait',
      () async {
        await notifier().resend();
        expect(harness.http.requests, isEmpty);

        harness.now = harness.now.add(const Duration(seconds: 31));
        harness.http.respond(200, {
          'data': {'expires_in': 300, 'resend_in': 60},
        });
        await notifier().resend();

        expect(harness.http.last.path, '/auth/otp/request');
        expect(state().wasResent, isTrue);
        expect(state().resendAt, harness.now.add(const Duration(seconds: 60)));
      },
    );
  });

  group('CompleteProfileNotifier', () {
    CompleteProfileState state() => container.read(completeProfileProvider);
    CompleteProfileNotifier notifier() =>
        container.read(completeProfileProvider.notifier);

    setUp(() => container.listen(completeProfileProvider, (_, _) {}));

    test(
      'requires a name and a well-formed email, without calling the API',
      () async {
        await notifier().save(name: '   ', email: 'not-an-email');

        expect(state().isNameMissing, isTrue);
        expect(state().isEmailInvalid, isTrue);
        expect(harness.http.requests, isEmpty);
      },
    );

    test('saves a trimmed name, leaves out an empty email', () async {
      harness.tokens.token = validToken();
      harness.http.respond(200, {'data': userJson()});
      await container.read(sessionControllerProvider.notifier).restore();

      harness.http.respond(200, {'data': userJson(name: 'Asha Rao')});
      await notifier().save(name: '  Asha Rao ', email: '');

      expect(harness.http.last.method, 'PATCH');
      expect(harness.http.lastBody, {'name': 'Asha Rao'});
      final session = container.read(sessionControllerProvider) as SignedIn;
      expect(session.user.name, 'Asha Rao');
    });

    test('shows the API validation on the field it names', () async {
      harness.http.respond(422, {
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'Invalid.',
          'details': {
            'email': ['The email has already been taken.'],
          },
        },
      });

      await notifier().save(name: 'Asha', email: 'asha@example.test');

      expect(state().isEmailInvalid, isTrue);
      expect(state().failure, isNull);
    });
  });
}
