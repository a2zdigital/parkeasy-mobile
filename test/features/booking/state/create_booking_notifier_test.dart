import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:app/features/booking/state/booking_draft.dart';
import 'package:app/features/booking/state/create_booking_notifier.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;
  late BookingDraft draft;
  var keysMade = 0;

  BookingDraft makeDraft({bool onsite = true, bool online = true}) {
    final quote = quoteJson()['data']! as Map<String, dynamic>
      ..['accepts_onsite_payment'] = onsite
      ..['accepts_online_payment'] = online;
    return BookingDraft(
      lot: ParkingLot.fromJson(lotJson()['data']! as Map<String, dynamic>),
      vehicleType: 'car',
      startAt: DateTime.utc(2026, 11, 2, 4, 30),
      endAt: DateTime.utc(2026, 11, 2, 6, 30),
      quote: Quote.fromJson(quote),
    );
  }

  CreateBookingState state() => container.read(createBookingProvider(draft));
  CreateBookingNotifier notifier() =>
      container.read(createBookingProvider(draft).notifier);
  List<RequestOptions> posts() =>
      harness.http.requests.where((r) => r.method == 'POST').toList();
  String? keyOf(RequestOptions request) =>
      request.headers['Idempotency-Key'] as String?;

  setUp(() {
    keysMade = 0;
    harness = Harness();
    container = ProviderContainer(
      overrides: [
        ...harness.overrides,
        idempotencyKeyFactoryProvider.overrideWithValue(
          () => 'key-${++keysMade}',
        ),
      ],
    );
    addTearDown(container.dispose);
    draft = makeDraft();
    container.listen(createBookingProvider(draft), (_, _) {});
  });

  test(
    'offers paying at the facility first, online when that is all there is',
    () {
      expect(state().paymentMode, PaymentMode.onSite);

      draft = makeDraft(onsite: false);
      container.listen(createBookingProvider(draft), (_, _) {});
      expect(state().paymentMode, PaymentMode.online);
    },
  );

  test(
    'books with the choice, the price the customer saw, and a key',
    () async {
      harness.http.respond(201, {'data': bookingJson()});

      await notifier().submit();

      final request = posts().single;
      expect(request.path, '/bookings');
      expect(request.data, {
        'parking_lot_id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
        'vehicle_type': 'car',
        'start_at': '2026-11-02T04:30:00Z',
        'end_at': '2026-11-02T06:30:00Z',
        'payment_mode': 'on_site',
        'expected_total_amount': '80.00',
      });
      expect(keyOf(request), 'key-1');
      expect(state().created?.reference, 'BK-K2M5XCN4');
      expect(state().isSubmitting, isFalse);
    },
  );

  test(
    'retrying after no answer repeats the same key, so one booking is made',
    () async {
      harness.http.fail(DioExceptionType.receiveTimeout);
      await notifier().submit();
      expect(state().failure?.code, ApiErrorCode.timeout);

      harness.http.fail(DioExceptionType.connectionError);
      await notifier().submit();

      harness.http.respond(201, {'data': bookingJson()});
      await notifier().submit();

      expect(posts().map(keyOf), ['key-1', 'key-1', 'key-1']);
      expect(state().created, isNotNull);
    },
  );

  test('"still in progress" also keeps the key', () async {
    harness.http.respond(409, {
      'error': {'code': 'REQUEST_IN_PROGRESS', 'message': 'Wait.'},
    });
    await notifier().submit();

    harness.http.respond(201, {'data': bookingJson()});
    await notifier().submit();

    expect(posts().map(keyOf), ['key-1', 'key-1']);
  });

  test(
    'a definite refusal ends the key; the next attempt is a new request',
    () async {
      harness.http.respond(409, {
        'error': {'code': 'SLOT_UNAVAILABLE', 'message': 'Taken.'},
      });
      await notifier().submit();
      expect(state().failure?.code, ApiErrorCode.slotUnavailable);
      expect(state().created, isNull);

      harness.http.respond(201, {'data': bookingJson()});
      await notifier().submit();

      expect(posts().map(keyOf), ['key-1', 'key-2']);
    },
  );

  test(
    'changing the payment mode is a different request with a new key',
    () async {
      harness.http.fail(DioExceptionType.receiveTimeout);
      await notifier().submit();

      notifier().selectPaymentMode(PaymentMode.online);
      expect(state().failure, isNull);

      harness.http.respond(201, {
        'data': bookingJson(status: 'awaiting_payment', paymentMode: 'online'),
      });
      await notifier().submit();

      expect(posts().map(keyOf), ['key-1', 'key-2']);
      expect((posts().last.data as Map)['payment_mode'], 'online');
    },
  );

  test('a second press while booking, or after it, sends nothing', () async {
    harness.http.respond(201, {'data': bookingJson()});

    final first = notifier().submit();
    final second = notifier().submit();
    await Future.wait([first, second]);
    await notifier().submit();

    expect(posts(), hasLength(1));
  });

  test('a changed price is reported, not booked', () async {
    harness.http.respond(409, {
      'error': {'code': 'QUOTE_EXPIRED', 'message': 'Price changed.'},
    });

    await notifier().submit();

    expect(state().failure?.code, ApiErrorCode.quoteExpired);
    expect(state().created, isNull);
  });
}
