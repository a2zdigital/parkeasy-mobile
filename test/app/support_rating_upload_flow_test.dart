import 'dart:typed_data';

import 'package:app/app/app.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/features/booking/ui/rate_booking_card.dart';
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

    testWidgets('a facility lists its reviews, newest first', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
      final lot = lotJson();
      (lot['data']! as Map<String, dynamic>)['rating'] = {
        'average': '4.0',
        'count': 2,
      };
      h.http.stubs['/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9'] = lot;
      h.http.stubs['/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9/ratings'] = {
        'data': [
          {
            'id': 'r2',
            'score': 5,
            'comment': 'Easy to find and safe.',
            'created_at': '2026-11-03T10:00:00Z',
          },
          {
            'id': 'r1',
            'score': 3,
            'comment': null,
            'created_at': '2026-11-01T10:00:00Z',
          },
        ],
        'summary': {'average': '4.0', 'count': 2},
      };
      await start(tester, h);

      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Easy to find and safe.'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );

      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('Easy to find and safe.'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RatingStars && w.score == 5),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is RatingStars && w.score == 3),
        findsOneWidget,
      );
      expect(find.textContaining('Nov'), findsWidgets);
    });

    testWidgets('a facility without reviews says so', (tester) async {
      final h = Harness(token: validToken());
      h.http.stubs['/parking-lots'] = searchJson([summaryJson()]);
      h.http.stubs['/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9'] = lotJson();
      h.http.stubs['/parking-lots/01M4JQSZSNAVTVCMS8A7AJ0WJ9/ratings'] = {
        'data': <Object?>[],
        'summary': {'average': null, 'count': 0},
      };
      await start(tester, h);

      await tester.tap(find.text('MG Road Metro Parking'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.textContaining('No reviews yet'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );

      expect(find.textContaining('No reviews yet'), findsOneWidget);
    });
  });

  group('owner uploads', () {
    testWidgets(
      'an applicant adds an Aadhaar card, and a wrong number asks them to verify it',
      (tester) async {
        final h = Harness(token: validToken());
        h.tokens.registrationIntent = 'owner';
        h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
        h.http.stubs['/owner/application/documents'] = {'data': <Object?>[]};
        await start(tester, h);
        expect(find.text('Not added yet'), findsNWidgets(2));

        await tester.ensureVisible(find.text('Add Aadhaar card').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Aadhaar card').first);
        await tester.pumpAndSettle();

        // A wrong check digit: nothing is sent, the owner is asked to verify it.
        await tester.enterText(find.byType(TextField).last, '234123412345');
        await tester.pumpAndSettle();
        expect(find.text('2341 2341 2345'), findsOneWidget);
        await tester.tap(find.text('Save card'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Please verify your Aadhaar number'),
          findsOneWidget,
        );
        expect(find.text('Choose a photo or PDF of the card.'), findsOneWidget);
        expect(writes(h), isEmpty);

        final card = {
          'id': 'd9',
          'type': 'identity',
          'file_name': 'aadhaar.jpg',
          'mime_type': 'image/jpeg',
          'size_bytes': 2048,
          'url': 'https://files.test/d9',
          'created_at': '2026-11-02T04:00:00Z',
          'document_number': 'XXXX XXXX 2346',
          'is_expired': false,
        };
        await tester.enterText(find.byType(TextField).last, '234123412346');
        h.files.next = pickedFile('aadhaar.jpg');
        await tester.tap(find.text('Choose a photo or PDF of the card'));
        await tester.pumpAndSettle();
        h.http.respond(201, {'data': card});
        h.http.stubs['/owner/application/documents'] = {
          'data': [card],
        };
        await tester.tap(find.text('Save card'));
        await tester.pumpAndSettle();

        final upload = writes(h).single;
        expect(upload.path, '/owner/application/documents');
        expect(Map.fromEntries((upload.data as FormData).fields), {
          'type': 'identity',
          'document_number': '234123412346',
          'identity_kind': 'aadhaar',
        });
        expect(find.text('Number: XXXX XXXX 2346'), findsOneWidget);
        expect(
          find.text('Not added yet'),
          findsOneWidget,
          reason: 'PAN card still to add',
        );

        // The second card: a valid PAN is saved and the owner goes to the home page.
        final pan = {
          ...card,
          'id': 'd10',
          'file_name': 'pan.jpg',
          'document_number': 'ABCPE1234F',
        };
        await tester.ensureVisible(find.text('Add PAN card').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add PAN card').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'abcpe1234f');
        h.files.next = pickedFile('pan.jpg');
        await tester.tap(find.text('Choose a photo or PDF of the card'));
        await tester.pumpAndSettle();
        h.http.respond(201, {'data': pan});
        h.http.stubs['/owner/application/documents'] = {
          'data': [card, pan],
        };
        await tester.tap(find.text('Save card'));
        await tester.pumpAndSettle();

        expect(Map.fromEntries((writes(h).last.data as FormData).fields), {
          'type': 'identity',
          'document_number': 'ABCPE1234F',
          'identity_kind': 'pan',
        });
        expect(
          find.textContaining('Your Aadhaar and PAN cards are saved'),
          findsOneWidget,
        );
        expect(
          find.text('Add PAN card'),
          findsNothing,
          reason: 'Left the application screen for home',
        );
      },
    );

    testWidgets(
      'an Aadhaar card is verified with the OTP sent to the Aadhaar-linked mobile, only with consent',
      (tester) async {
        final h = Harness(token: validToken());
        h.tokens.registrationIntent = 'owner';
        h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
        Map<String, dynamic> aadhaar({required bool waiting, String? status}) =>
            {
              'id': 'd9',
              'type': 'identity',
              'file_name': 'aadhaar.jpg',
              'mime_type': 'image/jpeg',
              'size_bytes': 2048,
              'created_at': '2026-11-02T04:00:00Z',
              'document_number': 'XXXX XXXX 2346',
              'identity_verification': {
                'status': status,
                'message': null,
                'awaits_aadhaar_otp': waiting,
              },
            };
        const meta = {
          'identity': {
            'pan_needs_date_of_birth': false,
            'aadhaar_needs_otp': true,
          },
        };
        h.http.stubs['/owner/application/documents'] = {
          'data': [aadhaar(waiting: true)],
          'meta': meta,
        };
        await start(tester, h);

        await tester.ensureVisible(find.text('Verify with OTP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify with OTP'));
        await tester.pumpAndSettle();

        // No consent: nothing is sent.
        await tester.enterText(find.byType(TextField).last, '234123412346');
        await tester.tap(find.text('Send OTP'));
        await tester.pumpAndSettle();
        expect(
          find.text('Please agree before we send the OTP.'),
          findsOneWidget,
        );
        expect(writes(h), isEmpty);

        await tester.tap(find.byType(Checkbox));
        h.http.respond(200, {
          'data': {
            'status': 'sent',
            'message': 'An OTP was sent.',
            'expires_in_seconds': 600,
          },
        });
        await tester.tap(find.text('Send OTP'));
        await tester.pumpAndSettle();
        final send = writes(h).single;
        expect(send.path, '/owner/application/documents/d9/aadhaar-otp');
        expect(send.data, {'aadhaar_number': '234123412346', 'consent': true});

        // A wrong OTP can be tried again.
        h.http.respond(200, {
          'data': {
            'status': 'otp_rejected',
            'message': 'The OTP is incorrect or has expired.',
            'attempts_left': 2,
          },
        });
        await tester.enterText(find.byType(TextField).last, '111111');
        await tester.pumpAndSettle();
        expect(find.textContaining('2 tries left'), findsOneWidget);

        h.http.respond(200, {
          'data': {'status': 'verified', 'message': 'Confirmed.'},
        });
        h.http.stubs['/owner/application/documents'] = {
          'data': [aadhaar(waiting: false, status: 'verified')],
          'meta': meta,
        };
        await tester.enterText(find.byType(TextField).last, '482913');
        await tester.pumpAndSettle();

        expect(writes(h).last.data, {'otp': '482913'});
        expect(find.text('Your Aadhaar is verified.'), findsOneWidget);
        expect(find.text('Verified'), findsOneWidget);
        expect(find.text('Verify with OTP'), findsNothing);
      },
    );

    testWidgets(
      'Aadhaar: number, then OTP, then the card file, then the result, then PAN',
      (tester) async {
        final h = Harness(token: validToken());
        h.tokens.registrationIntent = 'owner';
        h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
        const meta = {
          'identity': {
            'pan_needs_date_of_birth': false,
            'aadhaar_needs_otp': true,
          },
        };
        h.http.stubs['/owner/application/documents'] = {
          'data': <Object?>[],
          'meta': meta,
        };
        await start(tester, h);

        await tester.ensureVisible(find.text('Add Aadhaar card').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Aadhaar card').first);
        await tester.pumpAndSettle();

        // 1. The number and consent.
        await tester.enterText(find.byType(TextField).last, '234123412346');
        await tester.tap(find.byType(Checkbox));
        h.http.respond(200, {
          'data': {
            'status': 'sent',
            'message': 'Sent.',
            'expires_in_seconds': 600,
          },
        });
        await tester.tap(find.text('Send OTP'));
        await tester.pumpAndSettle();
        expect(writes(h).last.path, '/owner/application/aadhaar-otp');
        expect(writes(h).last.data, {
          'aadhaar_number': '234123412346',
          'consent': true,
        });

        // 2. The OTP, on the same sheet.
        h.http.respond(200, {
          'data': {'status': 'verified', 'message': 'Confirmed.'},
        });
        await tester.enterText(find.byType(TextField).last, '482913');
        await tester.pumpAndSettle();
        expect(writes(h).last.path, '/owner/application/aadhaar-otp/verify');
        expect(find.textContaining('OTP confirmed'), findsOneWidget);

        // 3. The file.
        final card = {
          'id': 'd9',
          'type': 'identity',
          'file_name': 'aadhaar.jpg',
          'mime_type': 'image/jpeg',
          'size_bytes': 2048,
          'created_at': '2026-11-02T04:00:00Z',
          'document_number': 'XXXX XXXX 2346',
          'identity_verification': {
            'status': 'verified',
            'message': 'Confirmed.',
            'awaits_aadhaar_otp': false,
          },
        };
        h.files.next = pickedFile('aadhaar.jpg');
        await tester.tap(find.text('Choose a photo or PDF of the card'));
        await tester.pumpAndSettle();
        h.http.respond(201, {'data': card});
        h.http.stubs['/owner/application/documents'] = {
          'data': [card],
          'meta': meta,
        };
        await tester.tap(find.text('Save card'));
        await tester.pumpAndSettle();
        expect(Map.fromEntries((writes(h).last.data as FormData).fields), {
          'type': 'identity',
          'document_number': '234123412346',
          'identity_kind': 'aadhaar',
        });

        // 4. The result, then on to the PAN details.
        expect(find.textContaining('Your Aadhaar is verified'), findsOneWidget);
        await tester.tap(find.text('Add PAN details'));
        await tester.pumpAndSettle();
        expect(find.text('Add PAN card'), findsWidgets);
        expect(find.text('PAN'), findsOneWidget);
      },
    );

    testWidgets('an identity card the picker cannot open is explained', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.tokens.registrationIntent = 'owner';
      h.http.stubs['/owner/application'] = ownerJson(status: 'pending');
      h.http.stubs['/owner/application/documents'] = {'data': <Object?>[]};
      await start(tester, h);
      h.files.problem = PickProblem.unreadable;

      await tester.ensureVisible(find.text('Add Aadhaar card').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Aadhaar card').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo or PDF of the card'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be opened'), findsOneWidget);
      expect(writes(h), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the documents page shows only the Aadhaar and PAN cards', (
      tester,
    ) async {
      final h = Harness(token: validToken());
      h.http.stubs['/owner/bookings'] = pageJson(const []);
      h.http.stubs['/owner/application'] = ownerJson();
      h.http.stubs['/owner/application/documents'] = {
        'data': [
          {
            'id': 'd1',
            'type': 'identity',
            'file_name': 'aadhaar.pdf',
            'mime_type': 'application/pdf',
            'size_bytes': 2048,
            'created_at': '2026-11-02T04:00:00Z',
            'document_number': 'XXXX XXXX 2346',
          },
        ],
      };
      await start(tester, h, roles: ['customer', 'owner']);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Number: XXXX XXXX 2346'), findsOneWidget);
      expect(find.text('Add PAN card'), findsOneWidget);
      expect(find.text('Add a document'), findsNothing);
      expect(find.text('Other documents'), findsNothing);
      // Approved: kept as the verification record.
      expect(find.byTooltip('Remove document'), findsNothing);
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
