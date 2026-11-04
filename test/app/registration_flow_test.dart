import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/auth/state/registration_role.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/owner/ui/owner_application_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  Future<void> launch(WidgetTester tester, Harness harness) async {
    await tester.pumpWidget(
      ProviderScope(overrides: harness.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startRegistration(
    WidgetTester tester,
    Harness harness,
    RegistrationRole role,
  ) async {
    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    final title = role == RegistrationRole.owner ? 'Parking Owner' : 'Customer';
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();

    harness.http.respond(202, {
      'data': {'expires_in': 300, 'resend_in': 30},
    });
    await tester.enterText(find.byType(TextField), '9000000001');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code'), findsOneWidget);

    harness.http.respond(200, sessionJson(newUser: true));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(harness.tokens.registrationIntent, role.storageValue);
  }

  Future<void> completeCustomerProfile(
    WidgetTester tester,
    Harness harness, {
    required int status,
    required Object response,
  }) async {
    harness.http.respond(status, response);
    await tester.enterText(find.byType(TextField).first, 'Asha Rao');
    await tester.enterText(find.byType(TextField).last, 'asha@example.test');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('welcome offers login and registration before role selection', (
    tester,
  ) async {
    final harness = Harness();
    await launch(tester, harness);

    expect(find.text('Already have an account? Log in'), findsOneWidget);
    expect(find.text('Create a new account'), findsOneWidget);

    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();
    expect(find.text('Parking Owner'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.textContaining('How would you like to use'), findsOneWidget);
    expect(harness.http.requests, isEmpty);
  });

  testWidgets('customer registration verifies OTP before saving details', (
    tester,
  ) async {
    final harness = Harness();
    await launch(tester, harness);
    await startRegistration(tester, harness, RegistrationRole.customer);

    await completeCustomerProfile(
      tester,
      harness,
      status: 200,
      response: {
        'data': userJson(name: 'Asha Rao', email: 'asha@example.test'),
      },
    );

    expect(find.text('Explore'), findsWidgets);
    expect(harness.tokens.registrationIntent, isNull);
    expect(harness.http.requests.map((request) => request.path).take(3), [
      '/auth/otp/request',
      '/auth/otp/verify',
      '/me',
    ]);
    final profileRequest = harness.http.requests.singleWhere(
      (request) => request.path == '/me',
    );
    expect(profileRequest.data, {
      'name': 'Asha Rao',
      'email': 'asha@example.test',
    });
  });

  testWidgets('owner registration submits supported application details', (
    tester,
  ) async {
    final harness = Harness();
    await launch(tester, harness);
    await startRegistration(tester, harness, RegistrationRole.owner);

    harness.http
      ..respond(200, {
        'data': userJson(name: 'Asha Rao', email: 'asha@example.test'),
      })
      ..respond(404, {
        'error': {
          'code': 'OWNER_PROFILE_NOT_FOUND',
          'message': 'No owner application.',
        },
      });
    await tester.enterText(find.byType(TextField).first, 'Asha Rao');
    await tester.enterText(find.byType(TextField).last, 'asha@example.test');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(OwnerApplicationScreen), findsOneWidget);
    expect(find.textContaining('+91 90000 00001'), findsOneWidget);
    expect(find.text('Contact phone'), findsNothing);
    final session = ProviderScope.containerOf(
      tester.element(find.byType(OwnerApplicationScreen)),
    ).read(sessionControllerProvider);
    expect(session, isA<SignedIn>());
    expect((session as SignedIn).user.isOwner, isFalse);

    harness.http.respond(201, {
      'data': {
        'id': '01M4JQSZSNAVTVCMS8A7AJ0OWNR',
        'business_name': 'Asha Parking',
        'contact_phone': '+919000000001',
        'verification_status': 'pending',
        'rejection_reason': null,
        'verified_at': null,
        'created_at': '2026-10-10T10:00:00Z',
      },
    });
    await tester.enterText(find.byType(TextField), 'Asha Parking');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send application'));
    await tester.pumpAndSettle();

    expect(find.text('Application under review'), findsOneWidget);
    expect(harness.http.last.path, '/owner/application');
    expect(harness.http.lastBody, {
      'business_name': 'Asha Parking',
      'contact_phone': '+919000000001',
    });
    expect(harness.tokens.registrationIntent, 'owner');
  });

  testWidgets('existing login does not ask the user to register again', (
    tester,
  ) async {
    final harness = Harness();
    await launch(tester, harness);

    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pumpAndSettle();
    harness.http.respond(202, {
      'data': {'expires_in': 300, 'resend_in': 30},
    });
    await tester.enterText(find.byType(TextField), '9000000001');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send code'));
    await tester.pumpAndSettle();

    harness.http.respond(200, sessionJson());
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Complete your profile'), findsNothing);
    expect(find.text('Parking Owner'), findsNothing);
    expect(harness.tokens.registrationIntent, isNull);
    expect(harness.http.requests.map((request) => request.path).take(2), [
      '/auth/otp/request',
      '/auth/otp/verify',
    ]);
  });

  testWidgets('failed customer profile save does not finish registration', (
    tester,
  ) async {
    final harness = Harness();
    await launch(tester, harness);
    await startRegistration(tester, harness, RegistrationRole.customer);

    await completeCustomerProfile(
      tester,
      harness,
      status: 503,
      response: {
        'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'Unavailable.'},
      },
    );

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(harness.tokens.registrationIntent, 'customer');
  });

  testWidgets('failed owner application stays retryable without false success', (
    tester,
  ) async {
    final harness = Harness();
    await launch(tester, harness);
    await startRegistration(tester, harness, RegistrationRole.owner);

    harness.http
      ..respond(200, {'data': userJson(name: 'Asha Rao')})
      ..respond(404, {
        'error': {'code': 'OWNER_PROFILE_NOT_FOUND', 'message': 'Not found.'},
      });
    await tester.enterText(find.byType(TextField).first, 'Asha Rao');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();

    harness.http.respond(503, {
      'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'Unavailable.'},
    });
    await tester.enterText(find.byType(TextField), 'Asha Parking');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send application'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tell us about your parking business. We review each application before you can list a facility.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Application under review'), findsNothing);
    expect(harness.tokens.registrationIntent, 'owner');
  });

  testWidgets(
    'owner onboarding resumes from saved intent and backend profile',
    (tester) async {
      final harness = Harness(token: validToken())
        ..tokens.registrationIntent = 'owner'
        ..http.respond(200, {'data': userJson()})
        ..http.stubs['/owner/application'] = {
          'data': {
            'id': '01M4JQSZSNAVTVCMS8A7AJ0OWNR',
            'business_name': 'Asha Parking',
            'contact_phone': '+919000000001',
            'verification_status': 'pending',
            'rejection_reason': null,
            'verified_at': null,
            'created_at': '2026-10-10T10:00:00Z',
          },
        };
      await launch(tester, harness);

      expect(find.text('Application under review'), findsOneWidget);
      expect(find.text('Already have an account? Log in'), findsNothing);
      expect(harness.tokens.registrationIntent, 'owner');
    },
  );
}
