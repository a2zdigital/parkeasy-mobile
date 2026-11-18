import 'dart:typed_data';

import 'package:app/app/app.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/owner/ui/owner_documents_section.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Help and support, rating a completed booking, and the owner's document
/// and photo uploads, through the real router and screens.
void main() {
  Future<void> start(
    WidgetTester tester,
    Harness h, {
    List<String> roles = const ['customer'],
  }) async {
    h.http.respond(200, {'data': userJson(roles: roles)});
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  List<RequestOptions> writes(Harness h) =>
      h.http.requests.where((r) => r.method != 'GET').toList();

  Map<String, dynamic> ticketJson({
    String status = 'open',
    List<Map<String, dynamic>> messages = const [],
  }) => {
    'id': '01M4JQSZSNAVTVCMS8A7AJ0TKT',
    'reference': 'ST-7K2M9QXP',
    'subject': 'Refund not received',
    'category': 'payment',
    'category_label': 'Payment or refund',
    'priority': 'medium',
    'status': status,
    'booking_id': null,
    'resolved_at': null,
    'last_message_at': '2026-11-02T04:10:00Z',
    'created_at': '2026-11-02T04:00:00Z',
    'messages': messages,
  };

  Map<String, dynamic> message(String body, {bool staff = false}) => {
    'id': 'm-${body.hashCode}',
    'from_staff': staff,
    'author': null,
    'body': body,
    'created_at': '2026-11-02T04:05:00Z',
  };

  group('help and support', () {
    testWidgets('a customer opens a ticket and reads the reply', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/support/tickets'] = {
        'data': <Object?>[],
        'meta': {'page': 1, 'per_page': 50, 'total': 0, 'last_page': 1},
      };
      h.http.stubs['/support/categories'] = {
        'data': [
          {'code': 'booking', 'name': 'Booking'},
          {'code': 'payment', 'name': 'Payment or refund'},
        ],
      };
      await start(tester, h);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Help and support'));
      await tester.tap(find.text('Help and support'));
      await tester.pumpAndSettle();
      expect(find.text('No questions yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(PrimaryButton, 'Contact support'));
      await tester.pumpAndSettle();

      // Nothing is sent until the form is complete.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Send'));
      await tester.pumpAndSettle();
      expect(find.text('Choose what it is about.'), findsOneWidget);
      expect(writes(h), isEmpty);

      await tester.tap(find.text('What is it about?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment or refund').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.bySemanticsLabel('Subject'),
          matching: find.byType(TextField),
        ),
        'Refund not received',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Details'),
        'I cancelled early but have not seen my refund.',
      );

      final opened = ticketJson(
        messages: [message('I cancelled early but have not seen my refund.')],
      );
      h.http.respond(201, {'data': opened});
      h.http.stubs['/support/tickets/${opened['id']}'] = {
        'data': ticketJson(
          status: 'in_progress',
          messages: [
            message('I cancelled early but have not seen my refund.'),
            message('Your refund was sent today.', staff: true),
          ],
        ),
      };
      await tester.tap(find.widgetWithText(PrimaryButton, 'Send'));
      await tester.pumpAndSettle();

      final sent = writes(h).single;
      expect(sent.path, '/support/tickets');
      expect(sent.data, {
        'category': 'payment',
        'subject': 'Refund not received',
        'description': 'I cancelled early but have not seen my refund.',
      });
      expect(find.text('ST-7K2M9QXP'), findsOneWidget);
      expect(find.text('Your refund was sent today.'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);

      h.http.respond(200, {
        'data': ticketJson(
          status: 'in_progress',
          messages: [
            message('I cancelled early but have not seen my refund.'),
            message('Your refund was sent today.', staff: true),
            message('Thank you!'),
          ],
        ),
      });
      await tester.enterText(
        find.widgetWithText(TextField, 'Reply'),
        'Thank you!',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(writes(h).last.path, '/support/tickets/${opened['id']}/messages');
      expect(writes(h).last.data, {'body': 'Thank you!'});
      expect(find.text('Thank you!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closed ticket cannot be answered', (tester) async {
      final h = Harness(token: validToken());
      final closed = ticketJson(status: 'closed', messages: [message('Hi')]);
      h.http.stubs['/support/tickets'] = {
        'data': [closed],
        'meta': {'page': 1, 'per_page': 50, 'total': 1, 'last_page': 1},
      };
      h.http.stubs['/support/tickets/${closed['id']}'] = {'data': closed};
      await start(tester, h);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Help and support'));
      await tester.tap(find.text('Help and support'));
      await tester.pumpAndSettle();
      expect(find.text('Closed'), findsOneWidget);
      await tester.tap(find.text('Refund not received'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This conversation is closed'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Reply'), findsNothing);
    });
  });

  group('rating', () {
    testWidgets('a completed booking can be rated once', (tester) async {
      final h = Harness(token: validToken());
      final done = bookingJson(status: 'completed');
      h.http.stubs['/bookings'] = bookingsJson([done]);
      h.http.stubs['/bookings/$bookingId'] = {'data': done};
      await start(tester, h);

      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BK-K2M5XCN4'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('How was your parking?'));
      final send = find.widgetWithText(SecondaryButton, 'Send rating');
      expect(
        tester.widget<SecondaryButton>(send).onPressed,
        isNull,
        reason: 'no score chosen yet',
      );

      await tester.ensureVisible(find.byTooltip('4 out of 5'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 out of 5'));
      await tester.pumpAndSettle();
      final comment = find.widgetWithText(TextField, 'Comment (optional)');
      await tester.dragUntilVisible(
        comment,
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.enterText(comment, 'Easy to find.');
      h.http.respond(201, {
        'data': {
          'id': 'r1',
          'score': 4,
          'comment': 'Easy to find.',
          'created_at': '2026-11-02T04:30:00Z',
        },
      });
      h.http.stubs['/bookings/$bookingId'] = {
        'data': bookingJson(status: 'completed', myRating: 4),
      };
      await tester.dragUntilVisible(
        send,
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.tap(send);
      await tester.pumpAndSettle();

      final rated = writes(h).single;
      expect(rated.path, '/bookings/$bookingId/rating');
      expect(rated.data, {'score': 4, 'comment': 'Easy to find.'});
      expect(find.text('Your rating'), findsOneWidget);
      expect(find.text('How was your parking?'), findsNothing);
    });

    testWidgets('a facility shows its score', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
      final lot = lotJson();
      (lot['data']! as Map<String, dynamic>)['rating'] = {
        'average': '4.5',
        'count': 12,
      };
      h.http.stubs['/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9'] = lot;
      await start(tester, h);

      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();

      expect(find.text('4.5 · 12 ratings'), findsOneWidget);
    });
  });

  group('owner uploads', () {
    testWidgets('an applicant adds and removes a document', (tester) async {
      final h = Harness(token: validToken());
      h.tokens.registrationIntent = 'owner';
      h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
      h.http.stubs['/owner/application/documents'] = {'data': <Object?>[]};
      await start(tester, h);
      expect(find.text('No documents yet.'), findsOneWidget);

      // Too large: refused before anything is sent.
      h.files.next = pickedFile('huge.pdf', sizeBytes: 6 * 1024 * 1024);
      await tester.ensureVisible(find.text('Add a document'));
      await tester.tap(find.text('Add a document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proof of identity'));
      await tester.pumpAndSettle();
      expect(find.textContaining('larger than 5 MB'), findsOneWidget);
      expect(writes(h), isEmpty);

      final document = {
        'id': 'd1',
        'type': 'identity',
        'file_name': 'aadhaar.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 2048,
        'url': 'https://files.test/d1',
        'created_at': '2026-11-02T04:00:00Z',
        'expires_on': '2030-01-31',
        'is_expired': false,
      };
      h.files.next = pickedFile('aadhaar.pdf');
      h.http.respond(201, {'data': document});
      h.http.stubs['/owner/application/documents'] = {
        'data': [document],
      };
      await tester.ensureVisible(find.text('Add a document'));
      await tester.tap(find.text('Add a document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proof of identity'));
      await tester.pumpAndSettle();
      expect(find.text('When does it expire?'), findsOneWidget);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final now = DateTime.now();

      final upload = writes(h).single;
      expect(upload.path, '/owner/application/documents');
      final form = upload.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'type': 'identity',
        'expires_on': isoDate(DateTime(now.year, now.month + 1, 15)),
      });
      expect(find.text('Expires 2030-01-31'), findsOneWidget);
      expect(form.files.single.key, 'document');
      expect(form.files.single.value.filename, 'aadhaar.pdf');
      expect(h.files.asked.last, ['pdf', 'jpg', 'jpeg', 'png']);
      expect(find.text('aadhaar.pdf · 2 KB'), findsOneWidget);

      h.http.respond(204, '');
      h.http.stubs['/owner/application/documents'] = {'data': <Object?>[]};
      await tester.tap(find.byTooltip('Remove document'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Remove document'),
        ),
      );
      await tester.pumpAndSettle();

      expect(writes(h).last.method, 'DELETE');
      expect(writes(h).last.path, '/owner/application/documents/d1');
      expect(find.text('No documents yet.'), findsOneWidget);
    });

    testWidgets('an owner links a parking licence to a selected facility', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.tokens.registrationIntent = 'owner';
      h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
      h.http.stubs['/owner/application/documents'] = {'data': <Object?>[]};
      h.http.stubs['/owner/parking-lots'] = pageJson([facilityJson()['data']!]);
      h.files.next = pickedFile('parking-permit.pdf');
      await start(tester, h);

      await tester.ensureVisible(find.text('Add a document'));
      await tester.tap(find.text('Add a document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parking licence or permit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();

      final document = {
        'id': 'd2',
        'type': 'licence',
        'file_name': 'parking-permit.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 2048,
        'url': 'https://files.test/d2',
        'created_at': '2026-11-02T04:00:00Z',
        'parking_lot': {'id': facilityId, 'name': 'MG Road Metro Parking'},
      };
      h.http.respond(201, {'data': document});
      h.http.stubs['/owner/application/documents'] = {
        'data': [document],
      };

      await tester.tap(find.text('When does it expire?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No expiry date'));
      await tester.pumpAndSettle();

      final upload = writes(h).single;
      expect(upload.path, '/owner/application/documents');
      expect(Map.fromEntries((upload.data as FormData).fields), {
        'type': 'licence',
        'parking_lot_id': facilityId,
      });
      expect(find.text('Facility: MG Road Metro Parking'), findsOneWidget);
    });

    testWidgets('an owner adds, reorders and removes facility photos', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/owner/bookings'] = pageJson(const []);
      final facility = facilityJson();
      const path = '/owner/parking-lots/$facilityId';
      h.http.stubs['/owner/parking-lots'] = pageJson([facility['data']]);
      h.http.stubs[path] = facility;
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Facilities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.textContaining('No photos yet'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      expect(find.textContaining('No photos yet'), findsOneWidget);

      Map<String, dynamic> withPhotos(List<String> ids) {
        final data = Map<String, dynamic>.from(
          facility['data']! as Map<String, dynamic>,
        );
        data['photos'] = [
          for (final id in ids) {'id': id, 'url': 'https://files.test/$id.jpg'},
        ];
        return {'data': data};
      }

      h.files.next = pickedFile('front.jpg');
      h.http.respond(201, withPhotos(['p1', 'p2']));
      await _tapAddPhoto(tester);
      await tester.pumpAndSettle();
      final upload = writes(h).single;
      expect(upload.path, '$path/photos');
      expect(h.files.askedImages.last, isTrue);
      expect((upload.data as FormData).files.single.key, 'photo');
      expect(find.text('Photo 1 of 2'), findsWidgets);

      h.http.respond(200, withPhotos(['p2', 'p1']));
      await tester.tap(find.byTooltip('Move later').first);
      await tester.pumpAndSettle();
      expect(writes(h).last.path, '$path/photos/order');
      expect(writes(h).last.data, {
        'photo_ids': ['p2', 'p1'],
      });

      h.http.respond(200, withPhotos(['p1']));
      await tester.tap(find.byTooltip('Remove photo').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Remove photo'),
        ),
      );
      await tester.pumpAndSettle();
      expect(writes(h).last.method, 'DELETE');
      expect(writes(h).last.path, '$path/photos/p2');
      expect(find.text('Photo 1 of 1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    /// An approved owner's draft facility, open at its photos.
    Future<Harness> atPhotos(WidgetTester tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/owner/bookings'] = pageJson(const []);
      final facility = facilityJson();
      h.http.stubs['/owner/parking-lots'] = pageJson([facility['data']]);
      h.http.stubs['/owner/parking-lots/$facilityId'] = facility;
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Facilities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Add a photo'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      return h;
    }

    for (final (problem, message) in [
      (PickProblem.unreadable, 'could not be opened'),
      (PickProblem.wrongType, 'Choose a JPG, PNG or WebP photo'),
      (PickProblem.tooLarge, 'larger than 5 MB'),
    ]) {
      testWidgets('a photo the picker cannot give is explained ($problem)', (
        tester,
      ) async {
        final h = await atPhotos(tester);
        h.files.problem = problem;

        await _tapAddPhoto(tester);
        await tester.pumpAndSettle();

        expect(find.textContaining(message), findsOneWidget);
        expect(writes(h), isEmpty);
        expect(tester.takeException(), isNull);

        // Nothing is stuck: the next photo goes up.
        final facility = facilityJson();
        final data = Map<String, dynamic>.from(
          facility['data']! as Map<String, dynamic>,
        );
        data['photos'] = [
          {'id': 'p1', 'url': 'https://files.test/p1.jpg'},
        ];
        h.files.next = pickedFile('front.jpg');
        h.http.respond(201, {'data': data});
        await _tapAddPhoto(tester);
        await tester.pumpAndSettle();
        expect(writes(h).single.path, '/owner/parking-lots/$facilityId/photos');
        expect(find.textContaining(message), findsNothing);
      });
    }

    testWidgets('an unreadable answer to an upload does not lock the photos', (
      tester,
    ) async {
      final h = await atPhotos(tester);
      h.files.next = pickedFile('front.jpg');
      // A body the app cannot read as a facility.
      h.http.respond(201, {
        'data': {'unexpected': true},
      });

      await _tapAddPhoto(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final add = tester.widget<TextAction>(
        find.widgetWithText(TextAction, 'Add a photo'),
      );
      expect(add.onPressed, isNotNull);
    });

    testWidgets('an approved owner adds documents later from Profile', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/owner/bookings'] = pageJson(const []);
      h.http.stubs['/owner/application'] = ownerJson();
      final document = {
        'id': 'd1',
        'type': 'business',
        'file_name': 'gst.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 2048,
        'url': 'https://files.test/d1',
        'created_at': '2026-11-02T04:00:00Z',
      };
      h.http.stubs['/owner/application/documents'] = {
        'data': [document],
      };
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('gst.pdf · 2 KB'), findsOneWidget);
      expect(
        find.textContaining('You can add more at any time'),
        findsOneWidget,
      );
      // Approved: kept as the verification record.
      expect(find.byTooltip('Remove document'), findsNothing);

      h.files.next = pickedFile('deed.pdf');
      h.http.respond(201, {'data': document});
      await tester.tap(find.text('Add a document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proof of property'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No expiry date'));
      await tester.pumpAndSettle();

      final upload = writes(h).single;
      expect(upload.path, '/owner/application/documents');
      expect(Map.fromEntries((upload.data as FormData).fields), {
        'type': 'property',
      });
      expect(h.files.askedImages.last, isFalse);
    });

    testWidgets('a document the picker cannot open is explained', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.tokens.registrationIntent = 'owner';
      h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
      await start(tester, h);
      h.files.problem = PickProblem.unreadable;

      await tester.ensureVisible(find.text('Add a document'));
      await tester.tap(find.text('Add a document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proof of identity'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be opened'), findsOneWidget);
      expect(writes(h), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('picked file names', () {
    test('a gallery file without an extension gets one from its content', () {
      expect(
        nameWithExtension(
          '1000012345',
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        '1000012345.jpg',
      );
      expect(
        nameWithExtension(
          'img',
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D]),
        ),
        'img.png',
      );
      expect(nameWithExtension('front.jpg', Uint8List(4)), 'front.jpg');
      expect(nameWithExtension('unknown', Uint8List(4)), 'unknown');
    });
  });
}

Future<void> _tapAddPhoto(WidgetTester tester) async {
  final button = find.text('Add a photo');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}
