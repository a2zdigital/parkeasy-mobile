import 'package:app/core/api/api_error_code.dart';
import 'package:app/features/search/state/explore_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;

  ExploreState state() => container.read(exploreProvider);
  ExploreNotifier notifier() => container.read(exploreProvider.notifier);
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  setUp(() {
    harness = Harness();
    harness.http.stubs.clear(); // These tests queue every answer themselves.
    container = harness.container();
    addTearDown(container.dispose);
  });

  Future<void> open() async {
    container.listen(exploreProvider, (_, _) {});
    await settle();
    await settle();
  }

  test('loads the first page around the configured origin', () async {
    harness.http.respond(
      200,
      searchJson([
        summaryJson(),
        summaryJson(id: 'b', name: 'Second'),
      ], lastPage: 3),
    );

    expect(container.read(exploreProvider).isLoading, isTrue);
    await open();

    expect(state().isLoading, isFalse);
    expect(state().items.map((i) => i.name), [
      'MG Road Metro Parking',
      'Second',
    ]);
    expect(state().hasMore, isTrue);
    expect(harness.http.last.uri.queryParameters, {
      'lat': '12.9716',
      'lng': '77.5946',
      'radius_km': '25.0',
      'page': '1',
    });
  });

  test('offers the vehicle types found in the results as filters', () async {
    harness.http.respond(
      200,
      searchJson([
        summaryJson(vehicles: ['car', 'two_wheeler']),
        summaryJson(id: 'b', vehicles: ['car']),
      ]),
    );
    await open();

    expect(state().vehicleTypes.map((v) => v.code), ['car', 'two_wheeler']);
  });

  test('an empty result is empty, not an error', () async {
    harness.http.respond(200, searchJson(const []));
    await open();

    expect(state().isEmpty, isTrue);
    expect(state().failure, isNull);
  });

  test('a failed first load is an error that can be retried', () async {
    harness.http.fail(DioExceptionType.connectionError);
    await open();

    expect(state().failure?.code, ApiErrorCode.network);
    expect(state().isEmpty, isFalse);

    harness.http.respond(200, searchJson([summaryJson()]));
    await notifier().load();

    expect(state().failure, isNull);
    expect(state().items, hasLength(1));
  });

  test('loads the next page and appends it', () async {
    harness.http.respond(200, searchJson([summaryJson()], lastPage: 2));
    await open();

    harness.http.respond(
      200,
      searchJson([summaryJson(id: 'b', name: 'Second')], page: 2, lastPage: 2),
    );
    await notifier().loadMore();

    expect(harness.http.last.uri.queryParameters['page'], '2');
    expect(state().items.map((i) => i.name), [
      'MG Road Metro Parking',
      'Second',
    ]);
    expect(state().hasMore, isFalse);

    await notifier().loadMore();
    expect(
      harness.http.requests,
      hasLength(2),
      reason: 'no request past the end',
    );
  });

  test('a failed next page keeps what is shown and can be retried', () async {
    harness.http.respond(200, searchJson([summaryJson()], lastPage: 2));
    await open();

    harness.http.fail(DioExceptionType.receiveTimeout);
    await notifier().loadMore();

    expect(state().items, hasLength(1));
    expect(state().loadMoreFailure?.code, ApiErrorCode.timeout);
    expect(state().failure, isNull);
    expect(state().hasMore, isTrue);
  });

  test('a failed refresh keeps the list', () async {
    harness.http.respond(200, searchJson([summaryJson()]));
    await open();

    harness.http.fail(DioExceptionType.connectionError);
    await notifier().load();

    expect(state().items, hasLength(1));
    expect(state().failure, isNull);
    expect(state().loadMoreFailure?.code, ApiErrorCode.network);
  });

  test('choosing a vehicle type searches again with the filter', () async {
    harness.http.respond(
      200,
      searchJson([
        summaryJson(vehicles: ['car', 'two_wheeler']),
      ]),
    );
    await open();

    harness.http.respond(200, searchJson(const []));
    await notifier().selectVehicleType('two_wheeler');

    expect(
      harness.http.last.uri.queryParameters['filter[vehicle_type]'],
      'two_wheeler',
    );
    expect(state().vehicleType, 'two_wheeler');
    expect(state().isEmpty, isTrue);
    expect(
      state().vehicleTypes,
      hasLength(2),
      reason: 'the filter choices stay when a filter finds nothing',
    );
  });
}
