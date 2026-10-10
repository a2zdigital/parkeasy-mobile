import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/owner/data/models/approval_status.dart';
import 'package:app/features/owner/data/models/operating_hour_input.dart';
import 'package:app/features/owner/state/owner_facility_notifier.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

void main() {
  const path = '/owner/parking-lots/$facilityId';
  const poolPath = '/owner/pools/01M4JQSZT0000000000000POOL';
  late Harness harness;
  late ProviderContainer container;

  OwnerFacilityState state() =>
      container.read(ownerFacilityProvider(facilityId)).value!;
  OwnerFacilityNotifier notifier() =>
      container.read(ownerFacilityProvider(facilityId).notifier);
  List<RequestOptions> writes() =>
      harness.http.requests.where((r) => r.method != 'GET').toList();

  Future<void> open(Map<String, dynamic> facility) async {
    harness.http.stubs[path] = facility;
    container.listen(ownerFacilityProvider(facilityId), (_, _) {});
    await harness.http.idle();
  }

  setUp(() {
    harness = Harness();
    container = harness.container();
    addTearDown(container.dispose);
  });

  test(
    'a draft or a rejected facility can be edited and submitted; one in review cannot be touched',
    () async {
      for (final (status, edit, submit) in [
        ('draft', true, true),
        ('rejected', true, true),
        ('pending', false, false),
        ('approved', true, false),
      ]) {
        final h = Harness();
        final c = h.container();
        h.http.stubs[path] = facilityJson(status: status);
        c.listen(ownerFacilityProvider(facilityId), (_, _) {});
        await h.http.idle();
        final value = c.read(ownerFacilityProvider(facilityId)).value!;

        expect(value.canEdit, edit, reason: status);
        expect(value.canSubmit, submit, reason: status);
        c.dispose();
      }
    },
  );

  test('adding spaces creates the pool, then sets each rate given', () async {
    await open(facilityJson());
    final pool = (lotJson()['data']! as Map)['pools'] as List<Object?>;
    harness.http
      ..respond(201, {'data': pool.first})
      ..respond(200, {'data': pool.first})
      ..respond(200, {'data': pool.first});
    harness.http.stubs[path] = facilityJson(withPool: true);

    await notifier().addPool(
      vehicleType: 'car',
      capacity: 40,
      hourly: Decimal.parse('40'),
      daily: Decimal.parse('250'),
    );

    expect(writes().map((r) => '${r.method} ${r.path}'), [
      'POST $path/pools',
      'PUT $poolPath/rates/hourly',
      'PUT $poolPath/rates/daily',
    ]);
    expect(writes()[0].data, {'vehicle_type': 'car', 'capacity': 40});
    expect(writes()[1].data, {'amount': '40.00'});
    expect(writes()[2].data, {'amount': '250.00'});
    expect(state().facility.lot.pools, hasLength(1));
  });

  test('a rate left empty is not sent', () async {
    await open(facilityJson());
    final pool = (lotJson()['data']! as Map)['pools'] as List<Object?>;
    harness.http
      ..respond(201, {'data': pool.first})
      ..respond(200, {'data': pool.first});

    await notifier().addPool(
      vehicleType: 'car',
      capacity: 10,
      hourly: Decimal.parse('40'),
    );

    expect(writes().map((r) => r.path), [
      '$path/pools',
      '$poolPath/rates/hourly',
    ]);
  });

  test('editing a pool sends only what changed', () async {
    await open(facilityJson(withPool: true)); // 40 spaces, 40.00/h, 250.00/day
    harness.http.respond(200, {'data': <String, Object?>{}});

    await notifier().updatePool(
      '01M4JQSZT0000000000000POOL',
      capacity: 40,
      hourly: Decimal.parse('40'),
      daily: Decimal.parse('300'),
    );

    expect(writes().map((r) => '${r.method} ${r.path}'), [
      'PUT $poolPath/rates/daily',
    ]);
    expect(writes().single.data, {'amount': '300.00'});
  });

  test('an unchanged pool sends nothing', () async {
    await open(facilityJson(withPool: true));

    await notifier().updatePool(
      '01M4JQSZT0000000000000POOL',
      capacity: 40,
      hourly: Decimal.parse('40.00'),
      daily: Decimal.parse('250.00'),
    );

    expect(writes(), isEmpty);
  });

  test('a refused pool is reported to the form', () async {
    await open(facilityJson(withPool: true));
    harness.http.respond(409, {
      'error': {'code': 'INVENTORY_POOL_EXISTS', 'message': 'Exists.'},
    });

    await expectLater(
      notifier().addPool(vehicleType: 'car', capacity: 5),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.inventoryPoolExists,
        ),
      ),
    );
  });

  test(
    'opening hours are sent for all seven days, closed days without times',
    () async {
      await open(facilityJson());
      harness.http.respond(200, {'data': <String, Object?>{}});

      await notifier().setHours([
        for (var day = 1; day <= 6; day++)
          OperatingHourInput(
            dayOfWeek: day,
            opensAt: '06:00',
            closesAt: '22:00',
          ),
        const OperatingHourInput(dayOfWeek: 7, isClosed: true),
      ]);

      final body = writes().single.data as Map;
      final hours = body['hours'] as List;
      expect(writes().single.method, 'PUT');
      expect(hours, hasLength(7));
      expect(hours.first, {
        'day_of_week': 1,
        'is_closed': false,
        'opens_at': '06:00',
        'closes_at': '22:00',
      });
      expect(hours.last, {'day_of_week': 7, 'is_closed': true});
    },
  );

  test('submitting moves the facility into review', () async {
    await open(facilityJson(withPool: true, withHours: true));
    harness.http.respond(200, {'data': <String, Object?>{}});
    harness.http.stubs[path] = facilityJson(
      status: 'pending',
      withPool: true,
      withHours: true,
    );

    await notifier().submit();

    expect(writes().single.path, '$path/submit');
    expect(state().facility.approvalStatus, ApprovalStatus.pending);
    expect(state().justSubmitted, isTrue);
    expect(state().canEdit, isFalse);
  });

  test('an incomplete facility is not submitted, and says why', () async {
    await open(facilityJson());
    harness.http.respond(409, {
      'error': {'code': 'PARKING_LOT_INCOMPLETE', 'message': 'Incomplete.'},
    });

    await notifier().submit();

    expect(state().failure?.code, ApiErrorCode.parkingLotIncomplete);
    expect(state().facility.approvalStatus, ApprovalStatus.draft);
    expect(state().isBusy, isFalse);
  });

  test('parseRate accepts amounts above zero with up to two decimals', () {
    expect(parseRate('40'), Decimal.parse('40'));
    expect(parseRate(' 40.5 '), Decimal.parse('40.5'));
    expect(parseRate('0.01'), Decimal.parse('0.01'));
    for (final bad in ['', '0', '0.00', '-5', '40.555', 'abc', '1,000', '.5']) {
      expect(parseRate(bad), isNull, reason: bad);
    }
  });
}
