import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/state/booking_details_notifier.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  setUp(() {
    harness = Harness();
    container = harness.container();
    addTearDown(container.dispose);
  });

  group('BookingsNotifier', () {
    BookingsState state() => container.read(bookingsProvider);

    test('loads newest first and pages by cursor', () async {
      harness.http.respond(
        200,
        bookingsJson([bookingJson()], nextCursor: 'next-1'),
      );
      container.listen(bookingsProvider, (_, _) {});
      await settle();

      expect(state().items, hasLength(1));
      expect(state().hasMore, isTrue);

      harness.http.respond(
        200,
        bookingsJson([bookingJson(id: 'second', reference: 'BK-2')]),
      );
      await container.read(bookingsProvider.notifier).loadMore();

      expect(harness.http.last.uri.queryParameters['cursor'], 'next-1');
      expect(state().items.map((b) => b.reference), ['BK-K2M5XCN4', 'BK-2']);
      expect(state().hasMore, isFalse);
    });

    test('no bookings is empty, not an error; a failure is an error', () async {
      harness.http.respond(200, bookingsJson(const []));
      container.listen(bookingsProvider, (_, _) {});
      await settle();
      expect(state().isEmpty, isTrue);

      harness.http.fail(DioExceptionType.connectionError);
      container.invalidate(bookingsProvider);
      await settle();
      expect(state().failure?.code, ApiErrorCode.network);
      expect(state().isEmpty, isFalse);
    });
  });

  group('BookingDetailsNotifier', () {
    BookingDetailsState state() =>
        container.read(bookingDetailsProvider(bookingId)).value!;
    BookingDetailsNotifier notifier() =>
        container.read(bookingDetailsProvider(bookingId).notifier);

    Future<void> open(Map<String, dynamic> booking) async {
      harness.http.respond(200, {'data': booking});
      container.listen(bookingDetailsProvider(bookingId), (_, _) {});
      await settle();
    }

    test('offers cancelling only where it can apply', () async {
      for (final (status, checkedIn, expected) in [
        ('pending_approval', null, true),
        ('awaiting_payment', null, true),
        ('confirmed', null, true),
        ('confirmed', '2026-11-02T04:25:00Z', false),
        ('completed', null, false),
        ('cancelled', null, false),
        ('rejected', null, false),
        ('expired', null, false),
        ('no_show', null, false),
        ('something_new', null, false),
      ]) {
        final h = Harness();
        final c = h.container();
        h.http.respond(200, {
          'data': bookingJson(status: status, checkedInAt: checkedIn),
        });
        c.listen(bookingDetailsProvider(bookingId), (_, _) {});
        await settle();

        expect(
          c.read(bookingDetailsProvider(bookingId)).value!.canCancel,
          expected,
          reason: '$status, checked in: $checkedIn',
        );
        c.dispose();
      }
    });

    test('cancelling shows the API result and its refund decision', () async {
      await open(bookingJson(paymentMode: 'online'));
      harness.http.respond(200, {
        'data': bookingJson(
          status: 'cancelled',
          paymentMode: 'online',
          refundEligible: true,
        ),
      });

      await notifier().cancel();

      expect(harness.http.last.method, 'POST');
      expect(harness.http.last.path, '/bookings/$bookingId/cancel');
      expect(state().booking.status, BookingStatus.cancelled);
      expect(state().booking.refundEligible, isTrue);
      expect(state().canCancel, isFalse);
    });

    test(
      'a refused cancellation keeps the booking and gives the reason',
      () async {
        await open(bookingJson());
        harness.http.respond(409, {
          'error': {'code': 'CANCELLATION_NOT_ALLOWED', 'message': 'Too late.'},
        });

        await notifier().cancel();

        expect(state().booking.status, BookingStatus.confirmed);
        expect(
          state().cancelFailure?.code,
          ApiErrorCode.cancellationNotAllowed,
        );
        expect(state().isCancelling, isFalse);
      },
    );

    test('a failed refresh keeps what is shown', () async {
      await open(bookingJson());
      harness.http.fail(DioExceptionType.connectionError);

      await notifier().refresh();

      expect(state().booking.reference, 'BK-K2M5XCN4');
    });
  });
}
