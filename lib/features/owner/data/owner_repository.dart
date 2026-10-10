import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/owner/data/models/earning_entry.dart';
import 'package:app/features/owner/data/models/onsite_collection_state.dart';
import 'package:app/features/owner/data/models/operating_hour_input.dart';
import 'package:app/features/owner/data/models/owner_application_input.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/models/parking_lot_input.dart';
import 'package:app/features/owner/data/models/parking_lot_options.dart';
import 'package:app/features/owner/data/models/parking_owner.dart';
import 'package:app/features/parking_lot/data/models/inventory_pool.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => OwnerRepository(ref.watch(apiClientProvider)),
);

/// What an owner can do to a booking at one of their facilities.
enum OwnerBookingAction {
  approve('approve'),
  reject('reject'),
  checkIn('check-in'),
  checkOut('check-out');

  const OwnerBookingAction(this.path);

  final String path;
}

class OwnerRepository {
  const OwnerRepository(this._api);

  final ApiClient _api;

  /// The signed-in user's owner application. Throws
  /// `OWNER_PROFILE_NOT_FOUND` when they have not applied.
  Future<ParkingOwner> application() async => ParkingOwner.fromJson(
    ApiClient.object(await _api.get('/owner/application')),
  );

  Future<ParkingOwner> apply(OwnerApplicationInput input) async =>
      ParkingOwner.fromJson(
        ApiClient.object(
          await _api.post('/owner/application', body: input.toJson()),
        ),
      );

  /// Bookings at the owner's facilities, newest first.
  Future<CursorPage<Booking>> bookings({
    BookingStatus? status,
    String? reference,
    String? cursor,
  }) async => CursorPage.fromJson(
    await _api.get(
      '/owner/bookings',
      query: {
        'filter[status]': status?.wire,
        'filter[reference]': reference,
        'cursor': cursor,
      },
    ),
    Booking.fromJson,
  );

  Future<Booking> booking(String id) async =>
      Booking.fromJson(ApiClient.object(await _api.get('/owner/bookings/$id')));

  Future<Booking> act(String id, OwnerBookingAction action) async =>
      Booking.fromJson(
        ApiClient.object(
          await _api.post(
            '/owner/bookings/$id/${action.path}',
            body: const <String, Object?>{},
          ),
        ),
      );

  /// What is due at the facility for a booking, and whether it was taken.
  Future<OnsiteCollectionState> collection(String id) async =>
      OnsiteCollectionState.fromJson(
        ApiClient.object(await _api.get('/owner/bookings/$id/collection')),
      );

  /// Records that the customer paid the booking's total at the facility.
  Future<void> recordCollection(String id) => _api.post(
    '/owner/bookings/$id/collection',
    body: const <String, Object?>{},
  );

  Future<CursorPage<OwnerParkingLot>> facilities({String? cursor}) async =>
      CursorPage.fromJson(
        await _api.get('/owner/parking-lots', query: {'cursor': cursor}),
        OwnerParkingLot.fromJson,
      );

  Future<OwnerEarnings> earnings() async => OwnerEarnings.fromJson(
    ApiClient.object(await _api.get('/owner/earnings')),
  );

  Future<CursorPage<EarningEntry>> earningEntries({String? cursor}) async =>
      CursorPage.fromJson(
        await _api.get('/owner/earnings/entries', query: {'cursor': cursor}),
        EarningEntry.fromJson,
      );

  // Facility editing -------------------------------------------------------

  /// The choices offered when creating or editing a facility.
  Future<ParkingLotOptions> facilityOptions() async =>
      ParkingLotOptions.fromJson(
        ApiClient.object(await _api.get('/owner/parking-lot-options')),
      );

  Future<OwnerParkingLot> facility(String id) async => OwnerParkingLot.fromJson(
    ApiClient.object(await _api.get('/owner/parking-lots/$id')),
  );

  /// Creates a draft. It is not visible to customers until it has been
  /// submitted and approved.
  Future<OwnerParkingLot> createFacility(ParkingLotInput input) async =>
      OwnerParkingLot.fromJson(
        ApiClient.object(
          await _api.post('/owner/parking-lots', body: input.toJson()),
        ),
      );

  Future<OwnerParkingLot> updateFacility(
    String id,
    ParkingLotInput input,
  ) async => OwnerParkingLot.fromJson(
    ApiClient.object(
      await _api.patch('/owner/parking-lots/$id', body: input.toJson()),
    ),
  );

  /// Replaces the opening hours. All seven days are sent.
  Future<void> setHours(String id, List<OperatingHourInput> hours) => _api.put(
    '/owner/parking-lots/$id/operating-hours',
    body: {
      'hours': [for (final day in hours) day.toJson()],
    },
  );

  Future<void> submitFacility(String id) => _api.post(
    '/owner/parking-lots/$id/submit',
    body: const <String, Object?>{},
  );

  Future<InventoryPool> createPool(
    String facilityId, {
    required String vehicleType,
    required int capacity,
  }) async => InventoryPool.fromJson(
    ApiClient.object(
      await _api.post(
        '/owner/parking-lots/$facilityId/pools',
        body: {'vehicle_type': vehicleType, 'capacity': capacity},
      ),
    ),
  );

  Future<void> updatePoolCapacity(String poolId, int capacity) =>
      _api.patch('/owner/pools/$poolId', body: {'capacity': capacity});

  /// Sets what one hour or one day costs. The amount is sent as a decimal
  /// string, like every amount.
  Future<void> setRate(String poolId, RateType type, Decimal amount) =>
      _api.put(
        '/owner/pools/$poolId/rates/${type.wire}',
        body: {'amount': amount.toStringAsFixed(2)},
      );
}
