import 'package:app/core/api/api_exception.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/owner/data/models/onsite_collection_state.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:app/features/owner/state/owner_lists.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ownerBookingProvider = AsyncNotifierProvider.autoDispose
    .family<OwnerBookingNotifier, OwnerBookingState, String>(
      OwnerBookingNotifier.new,
    );

class OwnerBookingState {
  const OwnerBookingState({
    required this.booking,
    this.collection,
    this.isBusy = false,
    this.failure,
  });

  final Booking booking;

  /// What is due at the facility. Null for bookings paid online.
  final OnsiteCollectionState? collection;

  /// An action is being sent; no other can start.
  final bool isBusy;
  final ApiException? failure;

  bool get canAnswerRequest => booking.status == BookingStatus.pendingApproval;

  bool get canCheckIn =>
      booking.status == BookingStatus.confirmed && booking.checkedInAt == null;

  bool get canCheckOut => booking.isCheckedIn;

  /// Payment at the facility can be recorded once, for a booking that is
  /// confirmed or already completed.
  bool get canRecordPayment {
    final collection = this.collection;
    if (collection == null || collection.collection != null) return false;
    return booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.completed;
  }
}

/// One booking at the owner's facility and the actions on it. Every
/// action is the API's: the app sends it and shows what comes back.
class OwnerBookingNotifier
    extends AutoDisposeFamilyAsyncNotifier<OwnerBookingState, String> {
  @override
  Future<OwnerBookingState> build(String arg) => _load();

  Future<OwnerBookingState> _load() async {
    final repository = ref.read(ownerRepositoryProvider);
    final booking = await repository.booking(arg);
    return OwnerBookingState(
      booking: booking,
      collection: booking.paymentMode == PaymentMode.onSite
          ? await repository.collection(arg)
          : null,
    );
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    try {
      state = AsyncData(await _load());
    } on ApiException catch (failure, stack) {
      if (current == null) state = AsyncError(failure, stack);
    }
  }

  Future<void> act(OwnerBookingAction action) =>
      _run((repository) => repository.act(arg, action));

  Future<void> recordPayment() =>
      _run((repository) => repository.recordCollection(arg));

  Future<void> _run(
    Future<Object?> Function(OwnerRepository repository) send,
  ) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;

    state = AsyncData(
      OwnerBookingState(
        booking: current.booking,
        collection: current.collection,
        isBusy: true,
      ),
    );
    try {
      await send(ref.read(ownerRepositoryProvider));
      // Reload both the booking and what is due, so the screen shows the
      // server's state rather than a guess at it.
      final reloaded = await _load();
      ref
        ..invalidate(ownerBookingsProvider)
        ..invalidate(ownerEarningsProvider)
        ..invalidate(ownerEarningEntriesProvider);
      state = AsyncData(reloaded);
    } on ApiException catch (failure) {
      state = AsyncData(
        OwnerBookingState(
          booking: current.booking,
          collection: current.collection,
          failure: failure,
        ),
      );
    }
  }
}
