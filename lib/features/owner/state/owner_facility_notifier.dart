import 'package:app/core/api/api_exception.dart';
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
  });

  final OwnerParkingLot facility;
  final bool isBusy;
  final ApiException? failure;

  /// True right after a successful submit, for a one-off confirmation.
  final bool justSubmitted;

  /// A facility in review is locked; the API refuses changes to it.
  bool get canEdit => facility.approvalStatus != ApprovalStatus.pending;

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

  /// Changes a pool's capacity and rates. Only what differs is sent.
  /// Throws [ApiException].
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
      await _setRates(
        poolId,
        hourly: hourly == existing(RateType.hourly) ? null : hourly,
        daily: daily == existing(RateType.daily) ? null : daily,
      );
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
