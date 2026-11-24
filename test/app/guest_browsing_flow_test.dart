import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// A guest browses parking without an account, is asked to sign in only
/// when they try to book, and comes back to the same facility afterwards.
void main() {
  const lotPath = '/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9';

  testWidgets('a guest browses, signs in to book, and returns to it', (
    tester,
  ) async {
    final h = Harness();
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    h.http.stubs[lotPath] = lotJson();
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse parking first'));
    await tester.pumpAndSettle();

    // Public search and details, without a token and without asking for
    // anything personal.
    expect(find.text('MG Road Metro Parking'), findsOneWidget);
    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();
    expect(find.text('Rates'), findsOneWidget);
    expect(
      h.http.requests.where((r) => r.path.contains('notifications')),
      isEmpty,
    );
    expect(
      h.http.requests.every((r) => r.headers['Authorization'] == null),
      isTrue,
    );

    // Booking needs an account.
    await tester.tap(find.widgetWithText(PrimaryButton, 'Choose time'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    h.http.respond(200, {
      'data': {'expires_in': 300, 'resend_in': 30},
    });
    await tester.enterText(find.byType(TextField), '9000000001');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send code'));
    await tester.pumpAndSettle();

    h.http
      ..respond(200, sessionJson())
      ..respond(200, quoteJson())
      ..respond(200, availabilityJson());
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    // Straight back to choosing a time at the same facility.
    expect(find.text('Choose time'), findsWidgets);
    expect(find.widgetWithText(PrimaryButton, 'Continue'), findsOneWidget);
  });

  testWidgets('a guest who opens Bookings is asked to sign in', (tester) async {
    final h = Harness();
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse parking first'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(h.http.requests.where((r) => r.path == '/bookings'), isEmpty);
  });
}
