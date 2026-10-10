import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/owner/data/models/earning_entry.dart';
import 'package:app/features/owner/data/models/onsite_collection_state.dart';
import 'package:app/features/owner/data/models/owner_application_input.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/models/parking_owner.dart';
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
    String? cursor,
  }) async => CursorPage.fromJson(
    await _api.get(
      '/owner/bookings',
      query: {'filter[status]': status?.wire, 'cursor': cursor},
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
}
