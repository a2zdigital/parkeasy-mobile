import 'dart:convert';

import 'package:app/app/app.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Numbered bays: the customer chooses one, the owner moves a booking to
/// another, and bays have types.
void main() {
  const lotPath = '/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9';

  Map<String, dynamic> withBays() {
    final json = availabilityJson();
    (json['data'] as Map<String, dynamic>)['bays'] = [
      {
        'id': 'BAY1',
        'label': 'A-1',
        'features': <String>[],
        'available': false,
      },
      {
        'id': 'BAY2',
        'label': 'A-2',
        'features': ['accessible'],
        'available': true,
      },
      {
        'id': 'BAY3',
        'label': 'A-3',
        'features': ['ev', 'covered'],
        'available': true,
      },
    ];
    return json;
  }

  Map<String, dynamic> body(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);

  testWidgets('a customer chooses an accessible bay and books it', (
    tester,
  ) async {
    final h = Harness(
      token: validToken(),
      now: DateTime.utc(2026, 11, 2, 4, 17),
    );
    h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
    h.http.stubs[lotPath] = lotJson();
    h.http.respond(200, {'data': userJson()});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MG Road Metro Parking'));
    await tester.pumpAndSettle();
    final quote = quoteJson();
    (quote['data'] as Map<String, dynamic>)
      ..['booking_mode'] = 'instant'
      ..['accepts_onsite_payment'] = true;
    h.http
      ..respond(200, quote)
      ..respond(200, withBays());
    await tester.tap(find.widgetWithText(PrimaryButton, 'Choose time'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a bay (optional)'), findsOneWidget);
    expect(find.text('A-1, taken'), findsOneWidget);
    final bay = find.text('A-2');
    await tester.ensureVisible(bay);
    await tester.tap(bay);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Bay'), findsOneWidget);
    expect(find.text('A-2'), findsOneWidget);

    h.http.respond(201, {'data': bookingJson(spaceLabel: 'A-2')});
    h.http.stubs['/bookings/$bookingId'] = {
      'data': bookingJson(spaceLabel: 'A-2'),
    };
    await tester.tap(find.text('Pay at the facility'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Book parking'));
    await tester.pumpAndSettle();

    final created = h.http.requests.firstWhere(
      (r) => r.method == 'POST' && r.path == '/bookings',
    );
    expect(body(created)['parking_space_id'], 'BAY2');
  });

  testWidgets('an owner moves a booking to another free bay', (tester) async {
    final h = Harness(token: validToken());
    final confirmed = bookingJson(spaceLabel: 'A-1');
    h.http.stubs['/owner/bookings'] = pageJson([confirmed]);
    h.http.stubs['/owner/bookings/$bookingId'] = {'data': confirmed};
    h.http.stubs['/owner/bookings/$bookingId/collection'] = collectionJson();
    h.http.stubs['$lotPath/availability'] = withBays();
    h.http.respond(200, {
      'data': userJson(roles: ['customer', 'owner']),
    });
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BK-K2M5XCN4'));
    await tester.pumpAndSettle();

    final move = find.text('Move to another bay');
    await tester.dragUntilVisible(
      move,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(move);
    await tester.pumpAndSettle();

    expect(find.text('Move to which bay?'), findsOneWidget);
    // A-1 is the booking's own bay and is taken: not offered.
    expect(find.text('A-1'), findsNothing);
    expect(find.text('EV charging, Covered'), findsOneWidget);

    h.http.respond(200, {'data': bookingJson(spaceLabel: 'A-3')});
    await tester.tap(find.text('A-3'));
    await tester.pumpAndSettle();

    final sent = h.http.requests.lastWhere((r) => r.method == 'POST');
    expect(sent.path, '/owner/bookings/$bookingId/move-bay');
    expect(body(sent), {'parking_space_id': 'BAY3'});
    expect(find.text('Moved to bay A-3.'), findsOneWidget);
  });
}
