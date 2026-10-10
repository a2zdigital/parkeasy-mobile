import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/profile/ui/profile_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// The whole sign-in journey through the real router, screens and state,
/// with only HTTP, storage and the clock faked.
void main() {
  Future<Harness> launch(WidgetTester tester, {Harness? harness}) async {
    final h = harness ?? Harness();
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('a new user signs in, gives a name and reaches the app', (
    tester,
  ) async {
    final h = await launch(tester);

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // An invalid number is explained and nothing is sent.
    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
    expect(h.http.requests, isEmpty);

    h.http.respond(200, {
      'data': {'expires_in': 300, 'resend_in': 30},
    });
    await tester.enterText(find.byType(TextField), '9000000001');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('+91 90000 00001'), findsOneWidget);
    expect(find.textContaining('new code in 30 s'), findsOneWidget);

    // A wrong code: explained, field cleared, still signed out.
    h.http.respond(422, {
      'error': {'code': 'OTP_INVALID', 'message': 'Wrong code.'},
    });
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(
      find.text("That code isn't right. Check it and try again."),
      findsOneWidget,
    );
    expect(h.tokens.token, isNull);

    // The right code, for a new user: asked for a name first.
    h.http.respond(200, sessionJson(newUser: true));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);
    expect(h.tokens.token?.value, '12|secret');

    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);

    h.http.respond(200, {'data': userJson(name: 'Asha Rao')});
    await tester.enterText(find.byType(TextField).first, 'Asha Rao');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
    expect(h.http.last.headers['authorization'], 'Bearer 12|secret');
  });

  testWidgets('a returning user with a stored token goes straight in', (
    tester,
  ) async {
    final h = Harness(token: validToken())
      ..http.respond(200, {'data': userJson()});

    await launch(tester, harness: h);

    expect(find.text('Get started'), findsNothing);
    expect(find.text('Explore'), findsWidgets);
  });

  testWidgets('signing out asks first, then returns to the start', (
    tester,
  ) async {
    final h = Harness(token: validToken())
      ..http.respond(200, {'data': userJson()});
    await launch(tester, harness: h);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('+91 90000 00001'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.tokens.token, isNotNull);

    h.http.respond(200, {'data': <String, Object?>{}});
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(h.tokens.token, isNull);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('offline at start-up: an explanation and a retry, not sign-in', (
    tester,
  ) async {
    final h = Harness(token: validToken())
      ..http.fail(DioExceptionType.connectionError);
    await launch(tester, harness: h);

    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsNothing);
    expect(h.tokens.token, isNotNull);

    h.http.respond(200, {'data': userJson()});
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
  });
}
