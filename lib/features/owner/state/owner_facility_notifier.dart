import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/features/owner/data/models/approval_status.dart';
import 'package:app/features/owner/data/models/operating_hour_input.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/models/parking_lot_input.dart';
import 'package:app/features/owner/data/models/parking_lot_options.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The vehicle types, amenities and booking modes an owner may choose.
final facilityOptionsProvider = FutureProvider.autoDispose<ParkingLotOptions>(
  (ref) => ref.watch(ownerRepositoryProvider).facilityOptions(),
);

final ownerFacilityProvider = AsyncNotifierProvider.autoDispose
    .family<OwnerFacilityNotifier, OwnerFacilityState, String>(
      OwnerFacilityNotifier.new,
    );

class OwnerFacilityState {
  const OwnerFacilityState({
    required this.facility,
    this.isBusy = false,
    this.failure,
    this.justSubmitted = false,
    this.photoProblem,
  });

  final OwnerParkingLot facility;
  final bool isBusy;
  final ApiException? failure;

  /// True right after a successful submit, for a one-off confirmation.
  final bool justSubmitted;

  /// Why the chosen photo was not sent, when it was not.
  final PickProblem? photoProblem;

  /// A facility in review is locked; the API refuses changes to it.
  bool get canEdit => facility.approvalStatus != ApprovalStatus.pending;

  /// Only a facility that was never submitted can be deleted.
  bool get canDelete => facility.approvalStatus == ApprovalStatus.draft;

  /// Pausing applies to a facility customers can find.
  bool get canPause => facility.approvalStatus == ApprovalStatus.approved;

  bool get canSubmit =>
      facility.approvalStatus == ApprovalStatus.draft ||
      facility.approvalStatus == ApprovalStatus.rejected;
}

/// One of the owner's facilities and every change to it. After each
/// change the facility is read again from the API, so the screen shows
/// what the server holds, including a status the change may have moved.
class OwnerFacilityNotifier
    extends AutoDisposeFamilyAsyncNotifier<OwnerFacilityState, String> {
  @override
  Future<OwnerFacilityState> build(String arg) async => OwnerFacilityState(
    facility: await ref.watch(ownerRepositoryProvider).facility(arg),
  );

  /// Saves the details form. Throws [ApiException] so the form can show
  /// field errors; nothing here is changed when it fails.
  Future<void> saveDetails(ParkingLotInput input) async {
    await ref.read(ownerRepositoryProvider).updateFacility(arg, input);
    await _reload();
  }

  /// Adds spaces for a vehicle type with its rates. Throws [ApiException].
  Future<void> addPool({
    required String vehicleType,
    required int capacity,
    Decimal? hourly,
    Decimal? daily,
  }) async {
    final repository = ref.read(ownerRepositoryProvider);
    final pool = await repository.createPool(
      arg,
      vehicleType: vehicleType,
      capacity: capacity,
    );
    try {
      await _setRates(pool.id, hourly: hourly, daily: daily);
    } finally {
      // The pool exists even if a rate failed: show it so it can be fixed.
      await _reload();
    }
  }

  /// Changes a pool's capacity and rates. Only what differs is sent; a
  /// rate left empty that was offered is ended. Throws [ApiException].
  Future<void> updatePool(
    String poolId, {
    required int capacity,
    Decimal? hourly,
    Decimal? daily,
  }) async {
    final current = state.valueOrNull?.facility.lot.pools
        .where((pool) => pool.id == poolId)
        .firstOrNull;
    final repository = ref.read(ownerRepositoryProvider);

    try {
      if (current == null || current.capacity != capacity) {
        await repository.updatePoolCapacity(poolId, capacity);
      }
      Decimal? existing(RateType type) => current?.rates
          .where((rate) => rate.rateType == type)
          .firstOrNull
          ?.amount;
      // New amounts first, so the pool never drops to no rate at all.
      await _setRates(
        poolId,
        hourly: hourly == existing(RateType.hourly) ? null : hourly,
        daily: daily == existing(RateType.daily) ? null : daily,
      );
      for (final (type, amount) in [
        (RateType.hourly, hourly),
        (RateType.daily, daily),
      ]) {
        if (amount == null && existing(type) != null) {
          await repository.endRate(poolId, type);
        }
      }
    } finally {
      await _reload();
    }
  }

  /// Replaces the opening hours. Throws [ApiException].
  Future<void> setHours(List<OperatingHourInput> hours) async {
    await ref.read(ownerRepositoryProvider).setHours(arg, hours);
    await _reload();
  }

  /// Sends the facility for review. A failure is kept in the state for
  /// the screen to explain.
  Future<void> submit() async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;

    state = AsyncData(
      OwnerFacilityState(facility: current.facility, isBusy: true),
    );
    try {
      await ref.read(ownerRepositoryProvider).submitFacility(arg);
      final facility = await ref.read(ownerRepositoryProvider).facility(arg);
      ref.invalidate(ownerFacilitiesProvider);
      state = AsyncData(
        OwnerFacilityState(facility: facility, justSubmitted: true),
      );
    } on ApiException catch (failure) {
      state = AsyncData(
        OwnerFacilityState(facility: current.facility, failure: failure),
      );
    }
  }

  /// Pauses or resumes the facility. A failure is kept in the state.
  Future<void> setPaused({required bool paused}) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;

    state = AsyncData(
      OwnerFacilityState(facility: current.facility, isBusy: true),
    );
    try {
      final facility = await ref
          .read(ownerRepositoryProvider)
          .setFacilityPaused(arg, paused: paused);
      ref.invalidate(ownerFacilitiesProvider);
      state = AsyncData(OwnerFacilityState(facility: facility));
    } on ApiException catch (failure) {
      state = AsyncData(
        OwnerFacilityState(facility: current.facility, failure: failure),
      );
    }
  }

  /// Deletes the draft. True when it is gone; a failure is kept in the
  /// state for the screen to explain.
  Future<bool> delete() async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return false;

    state = AsyncData(
      OwnerFacilityState(facility: current.facility, isBusy: true),
    );
    try {
      await ref.read(ownerRepositoryProvider).deleteFacility(arg);
      ref.invalidate(ownerFacilitiesProvider);
      return true;
    } on ApiException catch (failure) {
      state = AsyncData(
        OwnerFacilityState(facility: current.facility, failure: failure),
      );
      return false;
    }
  }

  /// Adds a photo at the end. A file over the limit is not sent.
  Future<void> addPhoto(PickedFile file) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    if (file.sizeBytes > maxUploadBytes) {
      state = AsyncData(
        OwnerFacilityState(
          facility: current.facility,
          photoProblem: PickProblem.tooLarge,
        ),
      );
      return;
    }
    await _photoChange(
      current,
      () => ref.read(ownerRepositoryProvider).addPhoto(arg, file),
    );
  }

  /// The picker could not give a usable photo; nothing was sent.
  void photoPickFailed(PickProblem problem) {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncData(
      OwnerFacilityState(facility: current.facility, photoProblem: problem),
    );
  }

  Future<void> removePhoto(String photoId) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    await _photoChange(
      current,
      () => ref.read(ownerRepositoryProvider).deletePhoto(arg, photoId),
    );
  }

  /// Moves a photo one place earlier (-1) or later (+1).
  Future<void> movePhoto(String photoId, int step) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    final ids = [for (final photo in current.facility.lot.photos) photo.id];
    final from = ids.indexOf(photoId);
    final to = from + step;
    if (from < 0 || to < 0 || to >= ids.length) return;
    ids
      ..removeAt(from)
      ..insert(to, photoId);
    await _photoChange(
      current,
      () => ref.read(ownerRepositoryProvider).reorderPhotos(arg, ids),
    );
  }

  Future<void> _photoChange(
    OwnerFacilityState current,
    Future<OwnerParkingLot> Function() change,
  ) async {
    state = AsyncData(
      OwnerFacilityState(facility: current.facility, isBusy: true),
    );
    try {
      final facility = await change();
      ref.invalidate(ownerFacilitiesProvider);
      state = AsyncData(OwnerFacilityState(facility: facility));
    } on ApiException catch (failure) {
      state = AsyncData(
        OwnerFacilityState(facility: current.facility, failure: failure),
      );
    } on Object {
      // Anything unexpected (a response the app cannot read) must not
      // leave the photos locked behind a spinner.
      state = AsyncData(
        OwnerFacilityState(
          facility: current.facility,
          failure: const ApiException(code: ApiErrorCode.unknown),
        ),
      );
    }
  }

  Future<void> _setRates(
    String poolId, {
    Decimal? hourly,
    Decimal? daily,
  }) async {
    final repository = ref.read(ownerRepositoryProvider);
    if (hourly != null) {
      await repository.setRate(poolId, RateType.hourly, hourly);
    }
    if (daily != null) {
      await repository.setRate(poolId, RateType.daily, daily);
    }
  }

  Future<void> _reload() async {
    try {
      final facility = await ref.read(ownerRepositoryProvider).facility(arg);
      ref.invalidate(ownerFacilitiesProvider);
      state = AsyncData(OwnerFacilityState(facility: facility));
    } on ApiException {
      // The change itself is reported by the caller; a failed re-read
      // leaves the last known state, and pull-to-refresh recovers.
    }
  }
}

/// Reads a rate typed by the owner. Null when the text is not an amount
/// above zero with at most two decimals; the API applies the same rule.
Decimal? parseRate(String text) {
  final trimmed = text.trim();
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(trimmed)) return null;
  final amount = Decimal.parse(trimmed);
  return amount > Decimal.zero ? amount : null;
}
