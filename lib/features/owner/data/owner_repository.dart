import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/gate/data/extra_time_payment.dart';
import 'package:app/features/owner/data/models/earning_entry.dart';
import 'package:app/features/owner/data/models/gst_registration.dart';
import 'package:app/features/owner/data/models/onsite_collection_state.dart';
import 'package:app/features/owner/data/models/operating_hour_input.dart';
import 'package:app/features/owner/data/models/owner_application_input.dart';
import 'package:app/features/owner/data/models/owner_document.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/models/owner_payout.dart';
import 'package:app/features/owner/data/models/parking_lot_input.dart';
import 'package:app/features/owner/data/models/parking_lot_options.dart';
import 'package:app/features/owner/data/models/parking_owner.dart';
import 'package:app/features/owner/data/models/parking_space.dart';
import 'package:app/features/parking_lot/data/models/allocation_mode.dart';
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

  /// The documents sent with the application, oldest first.
  Future<List<OwnerDocument>> documents() async {
    final data = (await _api.get('/owner/application/documents'))['data'];
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map)
          OwnerDocument.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<OwnerDocument> uploadDocument(
    OwnerDocumentType type,
    PickedFile file, {
    String? expiresOn,
    String? parkingLotId,
  }) async => OwnerDocument.fromJson(
    ApiClient.object(
      await _api.upload(
        '/owner/application/documents',
        field: 'document',
        file: file,
        fields: {
          'type': type.wire,
          'expires_on': ?expiresOn,
          'parking_lot_id': ?parkingLotId,
        },
      ),
    ),
  );

  /// Refused with INVALID_REVIEW_STATE once the application is approved.
  Future<void> deleteDocument(String id) =>
      _api.delete('/owner/application/documents/$id');

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

  /// Gate check-in by the code the customer shows. Spaces, dashes and
  /// case do not matter. Throws `CHECK_IN_CODE_NOT_FOUND` for a code that
  /// is not one of this owner's bookings.
  Future<Booking> checkOutByCode(
    String code, [
    CheckOutChoice choice = const CheckOutChoice(),
  ]) async => Booking.fromJson(
    ApiClient.object(
      await _api.post(
        '/owner/check-out',
        body: {'code': code, ...choice.toJson()},
      ),
    ),
  );

  /// Checks a check-out code and returns the parked booking; changes nothing.
  Future<Booking> verifyCheckOut(String code) async => Booking.fromJson(
    ApiClient.object(
      await _api.post('/owner/check-out/verify', body: {'code': code}),
    ),
  );

  Future<Booking> checkInByCode(String code) async => Booking.fromJson(
    ApiClient.object(await _api.post('/owner/check-in', body: {'code': code})),
  );

  Future<Booking> act(
    String id,
    OwnerBookingAction action, {
    CheckOutChoice choice = const CheckOutChoice(),
  }) async => Booking.fromJson(
    ApiClient.object(
      await _api.post(
        '/owner/bookings/$id/${action.path}',
        body: choice.toJson(),
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

  /// The owner's payout requests, newest first. Read-only.
  Future<CursorPage<OwnerPayout>> payouts({String? cursor}) async =>
      CursorPage.fromJson(
        await _api.get('/owner/payouts', query: {'cursor': cursor}),
        OwnerPayout.fromJson,
      );

  Future<CursorPage<EarningEntry>> earningEntries({String? cursor}) async =>
      CursorPage.fromJson(
        await _api.get('/owner/earnings/entries', query: {'cursor': cursor}),
        EarningEntry.fromJson,
      );

  // GST ------------------------------------------------------------------

  Future<List<GstRegistration>> gstRegistrations() async {
    final data = (await _api.get('/owner/gst-registrations'))['data'];
    return (data as List<dynamic>)
        .map((item) => GstRegistration.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GstRegistration> addGstRegistration({
    required String gstin,
    required String legalName,
  }) async => GstRegistration.fromJson(
    ApiClient.object(
      await _api.post(
        '/owner/gst-registrations',
        body: {'gstin': gstin, 'legal_name': legalName},
      ),
    ),
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

  /// Deletes a facility that was never submitted. The API refuses any
  /// other with `INVALID_REVIEW_STATE`.
  Future<void> deleteFacility(String id) =>
      _api.delete('/owner/parking-lots/$id');

  /// Pauses or resumes a facility. A paused facility is hidden from
  /// search and takes no new bookings; existing bookings stay.
  Future<OwnerParkingLot> setFacilityPaused(
    String id, {
    required bool paused,
  }) async => OwnerParkingLot.fromJson(
    ApiClient.object(
      await _api.post(
        '/owner/parking-lots/$id/${paused ? 'pause' : 'resume'}',
        body: const <String, Object?>{},
      ),
    ),
  );

  /// Adds a photo; it goes last. Returns the facility with its photos.
  Future<OwnerParkingLot> addPhoto(String id, PickedFile file) async =>
      OwnerParkingLot.fromJson(
        ApiClient.object(
          await _api.upload(
            '/owner/parking-lots/$id/photos',
            field: 'photo',
            file: file,
          ),
        ),
      );

  /// Puts every photo of the facility in this order.
  Future<OwnerParkingLot> reorderPhotos(
    String id,
    List<String> photoIds,
  ) async => OwnerParkingLot.fromJson(
    ApiClient.object(
      await _api.put(
        '/owner/parking-lots/$id/photos/order',
        body: {'photo_ids': photoIds},
      ),
    ),
  );

  Future<OwnerParkingLot> deletePhoto(String id, String photoId) async =>
      OwnerParkingLot.fromJson(
        ApiClient.object(
          await _api.delete('/owner/parking-lots/$id/photos/$photoId'),
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

  /// A pool's numbered bays, active and inactive, in label order.
  Future<List<ParkingSpace>> spaces(String poolId) async =>
      _spaceList(await _api.get('/owner/pools/$poolId/spaces'));

  /// Switches between any free space and numbered bays. Switching to
  /// numbered needs the first bays' [labels].
  Future<void> setAllocationMode(
    String poolId,
    AllocationMode mode, {
    List<String> labels = const [],
  }) => _api.put(
    '/owner/pools/$poolId/allocation-mode',
    body: {
      'allocation_mode': mode.wire,
      if (labels.isNotEmpty) 'labels': labels,
    },
  );

  /// Adds bays and returns all of the pool's bays.
  Future<List<ParkingSpace>> addSpaces(
    String poolId,
    List<String> labels,
  ) async => _spaceList(
    await _api.post('/owner/pools/$poolId/spaces', body: {'labels': labels}),
  );

  Future<void> setSpaceActive(String poolId, String spaceId, bool isActive) =>
      _api.patch(
        '/owner/pools/$poolId/spaces/$spaceId',
        body: {'is_active': isActive},
      );

  /// What the bay offers (accessible, ev, covered); replaces the list.
  Future<void> setSpaceFeatures(
    String poolId,
    String spaceId,
    List<String> features,
  ) => _api.patch(
    '/owner/pools/$poolId/spaces/$spaceId',
    body: {'features': features},
  );

  /// Only a bay that was never booked can be deleted.
  Future<void> deleteSpace(String poolId, String spaceId) =>
      _api.delete('/owner/pools/$poolId/spaces/$spaceId');

  static List<ParkingSpace> _spaceList(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map) ParkingSpace.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> updatePoolCapacity(String poolId, int capacity) =>
      _api.patch('/owner/pools/$poolId', body: {'capacity': capacity});

  /// Sets what one hour or one day costs. The amount is sent as a decimal
  /// string, like every amount.
  Future<void> setRate(String poolId, RateType type, Decimal amount) =>
      _api.put(
        '/owner/pools/$poolId/rates/${type.wire}',
        body: {'amount': amount.toStringAsFixed(2)},
      );

  /// Stops offering a rate. The API keeps it as history, and refuses to
  /// end the last rate of an active pool (`RATE_REQUIRED`).
  Future<void> endRate(String poolId, RateType type) =>
      _api.delete('/owner/pools/$poolId/rates/${type.wire}');
}
