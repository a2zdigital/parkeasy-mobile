import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/booking/state/choose_time_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

void main() {
  const lotId = '01M4JQSZSNAVTVCMS8A7AJ0WJ9';
  const lotPath = '/parking-lots/$lotId';
  late Harness harness;
  late ProviderContainer container;

  ChooseTimeState state() => container.read(chooseTimeProvider(lotId)).value!;
  ChooseTimeNotifier notifier() =>
      container.read(chooseTimeProvider(lotId).notifier);
  // Long enough for the faked HTTP round trips to finish.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  setUp(() {
    // 09:47 on Monday 2 November 2026 in India.
    harness = Harness(now: DateTime.utc(2026, 11, 2, 4, 17));
    harness.http.stubs[lotPath] = lotJson();
    container = harness.container();
    addTearDown(container.dispose);
  });

  Future<void> open({bool priced = true}) async {
    if (priced) {
      harness.http
        ..respond(200, quoteJson())
        ..respond(200, availabilityJson());
    }
    container.listen(chooseTimeProvider(lotId), (_, _) {});
    await settle();
  }

  test(
    'starts with the first vehicle type and two hours from the next half hour',
    () async {
      await open();

      expect(state().vehicleType, 'car');
      // 09:47 + 10 minutes = 09:57, so the next half hour is 10:00 IST.
      expect(state().startAt, DateTime.utc(2026, 11, 2, 4, 30));
      expect(state().endAt, DateTime.utc(2026, 11, 2, 6, 30));
    },
  );

  test(
    'asks the API for the price and the availability of that window',
    () async {
      await open();

      final quote = harness.http.requests.firstWhere(
        (r) => r.path == '/bookings/quote',
      );
      expect(quote.data, {
        'parking_lot_id': lotId,
        'vehicle_type': 'car',
        'start_at': '2026-11-02T04:30:00Z',
        'end_at': '2026-11-02T06:30:00Z',
      });
      expect(harness.http.last.path, '$lotPath/availability');
      expect(
        harness.http.last.uri.queryParameters['start_at'],
        '2026-11-02T04:30:00Z',
      );

      final priced = state().pricing as Priced;
      expect(priced.quote.total.toWire(), '80.00');
      expect(priced.availability.spacesLeft, 12);
    },
  );

  test(
    'a window the API refuses is reported with its reason, and availability is not asked',
    () async {
      harness.http.respond(422, {
        'error': {'code': 'OUTSIDE_OPERATING_HOURS', 'message': 'Closed.'},
      });
      await open(priced: false);

      final failed = state().pricing as PricingFailed;
      expect(failed.failure.code, ApiErrorCode.outsideOperatingHours);
      expect(
        harness.http.requests.where((r) => r.path.endsWith('/availability')),
        isEmpty,
      );
    },
  );

  test(
    'moving the arrival keeps the length of the stay and prices again',
    () async {
      await open();
      harness.http
        ..respond(200, quoteJson())
        ..respond(200, availabilityJson());

      notifier().setStart(DateTime.utc(2026, 11, 3, 9));
      expect(state().pricing, isA<PricingLoading>());
      await settle();

      expect(state().endAt, DateTime.utc(2026, 11, 3, 11));
      expect(state().pricing, isA<Priced>());
    },
  );

  test(
    'a departure at or before the arrival becomes the shortest stay',
    () async {
      await open();
      harness.http
        ..respond(200, quoteJson(total: '40.00', hours: 1))
        ..respond(200, availabilityJson());

      notifier().setEnd(state().startAt);
      await settle();

      expect(
        state().endAt.difference(state().startAt),
        const Duration(hours: 1),
      );
    },
  );

  test('changing the vehicle type asks for that type', () async {
    await open();
    harness.http
      ..respond(200, quoteJson(total: '30.00'))
      ..respond(200, availabilityJson(left: 0));

    notifier().setVehicleType('two_wheeler');
    await settle();

    final quote = harness.http.requests.lastWhere(
      (r) => r.path == '/bookings/quote',
    );
    expect((quote.data as Map)['vehicle_type'], 'two_wheeler');
    expect((state().pricing as Priced).availability.isAvailable, isFalse);
  });

  test('a network failure can be retried with the same choice', () async {
    harness.http.fail(DioExceptionType.connectionError);
    await open(priced: false);
    expect(
      (state().pricing as PricingFailed).failure.code,
      ApiErrorCode.network,
    );

    harness.http
      ..respond(200, quoteJson())
      ..respond(200, availabilityJson());
    notifier().retry();
    await settle();

    expect(state().pricing, isA<Priced>());
    expect(state().startAt, DateTime.utc(2026, 11, 2, 4, 30));
  });

  test('only the answer to the latest choice is kept', () async {
    await open();
    // Two quick changes: answers arrive in order, the first must be dropped.
    harness.http
      ..respond(200, quoteJson(total: '11.00'))
      ..respond(200, quoteJson(total: '22.00'))
      ..respond(200, availabilityJson())
      ..respond(200, availabilityJson());

    notifier()
      ..setStart(DateTime.utc(2026, 11, 4, 9))
      ..setStart(DateTime.utc(2026, 11, 5, 9));
    await settle();

    expect(state().startAt, DateTime.utc(2026, 11, 5, 9));
    expect((state().pricing as Priced).quote.total.toWire(), '22.00');
  });
}
