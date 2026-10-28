import 'dart:async';

import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/profile/ui/edit_profile_screen.dart';
import 'package:app/features/profile/ui/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  Future<Harness> openProfile(WidgetTester tester) async {
    final harness = Harness(token: validToken())
      ..http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: harness.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('opens name-only profile editing from Profile', (tester) async {
    await openProfile(tester);

    expect(find.text('Edit profile'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Asha',
    );
    expect(
      find.text("Phone number and email can't be changed here."),
      findsOneWidget,
    );
  });

  testWidgets('validates a blank name without sending an update', (
    tester,
  ) async {
    final harness = await openProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);

    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a name between 2 and 120 characters.'),
      findsOneWidget,
    );
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      harness.http.requests.where(
        (request) => request.method == 'PATCH' && request.path == '/me',
      ),
      isEmpty,
    );
  });

  testWidgets('saves the name, navigates back to Profile, and shows success', (
    tester,
  ) async {
    final harness = await openProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    harness.http.respond(200, {'data': userJson(name: 'Asha Rao')});
    await tester.enterText(find.byType(TextField), '  Asha Rao  ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Profile updated.'), findsOneWidget);
    final update = harness.http.last;
    expect(update.method, 'PATCH');
    expect(update.path, '/me');
    expect(harness.http.lastBody, {'name': 'Asha Rao'});
  });

  testWidgets('shows a loading state while the profile update is pending', (
    tester,
  ) async {
    final harness = await openProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    final releaseResponse = Completer<void>();
    harness.http.respondLater(200, {
      'data': userJson(name: 'Asha Rao'),
    }, release: releaseResponse);
    await tester.enterText(find.byType(TextField), 'Asha Rao');
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
      isTrue,
    );

    releaseResponse.complete();
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('prevents duplicate submissions while save is in progress', (
    tester,
  ) async {
    final harness = await openProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    final releaseResponse = Completer<void>();
    harness.http.respondLater(200, {
      'data': userJson(name: 'Asha Rao'),
    }, release: releaseResponse);

    await tester.enterText(find.byType(TextField), 'Asha Rao');
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.isLoading, isTrue);
    expect(button.onPressed, isNull);

    // Attempt second tap while submitting
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.pump();

    releaseResponse.complete();
    await tester.pumpAndSettle();

    expect(
      harness.http.requests
          .where(
            (request) => request.method == 'PATCH' && request.path == '/me',
          )
          .length,
      1,
    );

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('shows an API failure and reference without changing Profile', (
    tester,
  ) async {
    final harness = await openProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    harness.http.respond(503, {
      'error': {
        'code': 'SERVICE_UNAVAILABLE',
        'message': 'Unavailable.',
        'request_id': 'profile-update-ref',
      },
    });
    await tester.enterText(find.byType(TextField), 'Asha Rao');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('Profile updated.'), findsNothing);
    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Reference: profile-update-ref'), findsOneWidget);
  });

  testWidgets('shows server field validation on the name field', (
    tester,
  ) async {
    final harness = await openProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    harness.http.respond(422, {
      'error': {
        'code': 'VALIDATION_FAILED',
        'message': 'Invalid.',
        'details': {
          'name': ['Name is not accepted.'],
        },
      },
    });
    await tester.enterText(find.byType(TextField), 'Asha Rao');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('Profile updated.'), findsNothing);
    expect(
      find.text('Enter a name between 2 and 120 characters.'),
      findsOneWidget,
    );
  });
}
