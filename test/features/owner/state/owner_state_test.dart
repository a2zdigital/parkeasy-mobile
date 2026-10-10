import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/owner/data/models/verification_status.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_application_notifier.dart';
import 'package:app/features/owner/state/owner_booking_notifier.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;

  setUp(() {
    harness = Harness();
    container = harness.container();
    addTearDown(container.dispose);
  });

  group('owner application', () {
    OwnerApplicationState state() =>
        container.read(ownerApplicationProvider).value!;
    OwnerApplicationNotifier notifier() =>
        container.read(ownerApplicationProvider.notifier);

    Future<void> open() async {
      container.listen(ownerApplicationProvider, (_, _) {});
      await harness.http.idle();
    }

    test('"has not applied" is the form, not an error', () async {
      harness.http.respond(404, {
        'error': {'code': 'OWNER_PROFILE_NOT_FOUND', 'message': 'None.'},
      });
      await open();

      expect(state().application, isNull);
    });

    test('checks the form before sending', () async {
      harness.http.respond(404, {
        'error': {'code': 'OWNER_PROFILE_NOT_FOUND', 'message': 'None.'},
      });
      await open();
      final sent = harness.http.requests.length;

      await notifier().apply(businessName: '  ', contactPhone: '123');

      expect(state().isNameMissing, isTrue);
      expect(state().isPhoneInvalid, isTrue);
      expect(harness.http.requests, hasLength(sent));
    });

    test('applies with a trimmed name and an E.164 phone', () async {
      harness.http.respond(404, {
        'error': {'code': 'OWNER_PROFILE_NOT_FOUND', 'message': 'None.'},
      });
      await open();
      harness.http.respond(201, ownerJson(status: 'pending'));

      await notifier().apply(
        businessName: ' Ravi Parking Services ',
        contactPhone: '90000 00002',
      );

      expect(harness.http.lastBody, {
        'business_name': 'Ravi Parking Services',
        'contact_phone': '+919000000002',
      });
      expect(
        state().application?.verificationStatus,
        VerificationStatus.pending,
      );
    });

    test(
      'an approved application refreshes the user, who now has the owner role',
      () async {
        harness.http
          ..respond(200, ownerJson())
          ..respond(200, {
            'data': userJson(roles: ['customer', 'owner']),
          });
        await open();

        expect(
          state().application?.verificationStatus,
          VerificationStatus.approved,
        );
        expect(harness.http.last.path, '/me');
      },
    );
  });

  group('owner bookings list', () {
    test(
      'opens on requests waiting, and a new filter starts the list again',
      () async {
        harness.http.respond(200, pageJson(const []));
        container.listen(ownerBookingsProvider, (_, _) {});
        await harness.http.idle();

        expect(
          harness.http.last.uri.queryParameters['filter[status]'],
          'pending_approval',
        );

        harness.http.respond(200, pageJson([bookingJson()]));
        container.read(ownerBookingFilterProvider.notifier).state =
            BookingStatus.confirmed;
        await harness.http.idle();

        expect(
          harness.http.last.uri.queryParameters['filter[status]'],
          'confirmed',
        );
        expect(container.read(ownerBookingsProvider).items, hasLength(1));

        harness.http.respond(200, pageJson(const []));
        container.read(ownerBookingFilterProvider.notifier).state = null;
        await harness.http.idle();

        expect(
          harness.http.last.uri.queryParameters.containsKey('filter[status]'),
          isFalse,
        );
      },
    );
  });

  group('owner booking', () {
    const path = '/owner/bookings/$bookingId';
    OwnerBookingState state() =>
        container.read(ownerBookingProvider(bookingId)).value!;
    OwnerBookingNotifier notifier() =>
        container.read(ownerBookingProvider(bookingId).notifier);

    Future<void> open(
      Map<String, dynamic> booking, {
      Map<String, dynamic>? collection,
    }) async {
      harness.http.stubs[path] = {'data': booking};
      if (collection != null) {
        harness.http.stubs['$path/collection'] = collection;
      }
      container.listen(ownerBookingProvider(bookingId), (_, _) {});
      await harness.http.idle();
    }

    test('offers only the actions that apply to the booking state', () async {
      Future<OwnerBookingState> stateFor(
        Map<String, dynamic> booking, {
        Map<String, dynamic>? collection,
      }) async {
        final h = Harness();
        final c = h.container();
        h.http.stubs[path] = {'data': booking};
        if (collection != null) h.http.stubs['$path/collection'] = collection;
        c.listen(ownerBookingProvider(bookingId), (_, _) {});
        await h.http.idle();
        final value = c.read(ownerBookingProvider(bookingId)).value!;
        c.dispose();
        return value;
      }

      final request = await stateFor(
        bookingJson(status: 'pending_approval', paymentMode: 'online'),
      );
      expect(request.canAnswerRequest, isTrue);
      expect(request.canCheckIn, isFalse);
      expect(request.canRecordPayment, isFalse);

      final confirmed = await stateFor(
        bookingJson(),
        collection: collectionJson(),
      );
      expect(confirmed.canCheckIn, isTrue);
      expect(confirmed.canCheckOut, isFalse);
      expect(confirmed.canRecordPayment, isTrue);

      final parked = await stateFor(
        bookingJson(checkedInAt: '2026-11-02T04:25:00Z'),
        collection: collectionJson(collected: true),
      );
      expect(parked.canCheckIn, isFalse);
      expect(parked.canCheckOut, isTrue);
      expect(parked.canRecordPayment, isFalse, reason: 'already collected');

      final cancelled = await stateFor(
        bookingJson(status: 'cancelled'),
        collection: collectionJson(),
      );
      expect(cancelled.canCheckIn, isFalse);
      expect(cancelled.canRecordPayment, isFalse);
    });

    test(
      'a booking paid online has nothing to collect, and is not asked',
      () async {
        await open(bookingJson(paymentMode: 'online'));

        expect(state().collection, isNull);
        expect(
          harness.http.requests.any((r) => r.path.endsWith('/collection')),
          isFalse,
        );
      },
    );

    test(
      'an action is sent, then the booking is reloaded from the API',
      () async {
        await open(bookingJson(), collection: collectionJson());
        harness.http.respond(200, {
          'data': bookingJson(checkedInAt: '2026-11-02T04:25:00Z'),
        });
        harness.http.stubs[path] = {
          'data': bookingJson(checkedInAt: '2026-11-02T04:25:00Z'),
        };

        await notifier().act(OwnerBookingAction.checkIn);

        expect(
          harness.http.requests.any(
            (r) => r.method == 'POST' && r.path == '$path/check-in',
          ),
          isTrue,
        );
        expect(state().canCheckOut, isTrue);
        expect(state().isBusy, isFalse);
      },
    );

    test('recording payment shows it as collected', () async {
      await open(bookingJson(), collection: collectionJson());
      harness.http.respond(201, {'data': <String, Object?>{}});
      harness.http.stubs['$path/collection'] = collectionJson(collected: true);

      await notifier().recordPayment();

      expect(state().collection?.collection, isNotNull);
      expect(state().canRecordPayment, isFalse);
    });

    test('a refused action keeps the booking and gives the reason', () async {
      await open(bookingJson(), collection: collectionJson());
      harness.http.respond(409, {
        'error': {'code': 'CHECK_IN_NOT_ALLOWED', 'message': 'Too early.'},
      });

      await notifier().act(OwnerBookingAction.checkIn);

      expect(state().failure?.code, ApiErrorCode.checkInNotAllowed);
      expect(state().canCheckIn, isTrue);
      expect(state().isBusy, isFalse);
    });
  });
}
