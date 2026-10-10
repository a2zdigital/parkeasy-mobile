import 'package:app/core/api/pagination.dart';
import 'package:app/core/state/cursor_list.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/owner/data/models/earning_entry.dart';
import 'package:app/features/owner/data/models/owner_earnings.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The status the owner's booking list is filtered by; null shows all.
/// Requests waiting for an answer are what an owner must act on, so the
/// list opens on them.
final ownerBookingFilterProvider = StateProvider.autoDispose<BookingStatus?>(
  (ref) => BookingStatus.pendingApproval,
);

/// A booking reference typed at the gate. When set, it replaces the
/// status filter: the owner is looking for one booking, whatever its state.
final ownerBookingReferenceProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final ownerBookingsProvider =
    NotifierProvider.autoDispose<
      OwnerBookingsNotifier,
      CursorListState<Booking>
    >(OwnerBookingsNotifier.new);

class OwnerBookingsNotifier extends CursorListNotifier<Booking> {
  @override
  void watchInputs() {
    ref
      ..watch(ownerBookingFilterProvider)
      ..watch(ownerBookingReferenceProvider);
  }

  @override
  Future<CursorPage<Booking>> fetchPage(String? cursor) {
    final reference = ref.read(ownerBookingReferenceProvider);
    return ref
        .read(ownerRepositoryProvider)
        .bookings(
          status: reference == null
              ? ref.read(ownerBookingFilterProvider)
              : null,
          reference: reference,
          cursor: cursor,
        );
  }
}

final ownerFacilitiesProvider =
    NotifierProvider.autoDispose<
      OwnerFacilitiesNotifier,
      CursorListState<OwnerParkingLot>
    >(OwnerFacilitiesNotifier.new);

class OwnerFacilitiesNotifier extends CursorListNotifier<OwnerParkingLot> {
  @override
  Future<CursorPage<OwnerParkingLot>> fetchPage(String? cursor) =>
      ref.read(ownerRepositoryProvider).facilities(cursor: cursor);
}

final ownerEarningsProvider = FutureProvider.autoDispose<OwnerEarnings>(
  (ref) => ref.watch(ownerRepositoryProvider).earnings(),
);

final ownerEarningEntriesProvider =
    NotifierProvider.autoDispose<
      OwnerEarningEntriesNotifier,
      CursorListState<EarningEntry>
    >(OwnerEarningEntriesNotifier.new);

class OwnerEarningEntriesNotifier extends CursorListNotifier<EarningEntry> {
  @override
  Future<CursorPage<EarningEntry>> fetchPage(String? cursor) =>
      ref.read(ownerRepositoryProvider).earningEntries(cursor: cursor);
}
