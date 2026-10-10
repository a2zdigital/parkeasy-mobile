import 'package:app/core/api/api_exception.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingDetailsProvider = AsyncNotifierProvider.autoDispose
    .family<BookingDetailsNotifier, BookingDetailsState, String>(
      BookingDetailsNotifier.new,
    );

class BookingDetailsState {
  const BookingDetailsState({
    required this.booking,
    this.isCancelling = false,
    this.cancelFailure,
  });

  final Booking booking;
  final bool isCancelling;
  final ApiException? cancelFailure;

  /// Whether to offer cancelling. The API has the final word; this only
  /// hides the action where it can never apply.
  bool get canCancel => switch (booking.status) {
    BookingStatus.pendingApproval || BookingStatus.awaitingPayment => true,
    BookingStatus.confirmed => !booking.isCheckedIn,
    _ => false,
  };
}

class BookingDetailsNotifier
    extends AutoDisposeFamilyAsyncNotifier<BookingDetailsState, String> {
  @override
  Future<BookingDetailsState> build(String arg) async => BookingDetailsState(
    booking: await ref.watch(bookingRepositoryProvider).find(arg),
  );

  /// Pull to refresh: the status may have changed on the server.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    try {
      final booking = await ref.read(bookingRepositoryProvider).find(arg);
      state = AsyncData(BookingDetailsState(booking: booking));
    } on ApiException catch (failure, stack) {
      // Keep what is shown when a refresh fails.
      if (current == null) state = AsyncError(failure, stack);
    }
  }

  Future<void> cancel() async {
    final current = state.valueOrNull;
    if (current == null || current.isCancelling) return;

    state = AsyncData(
      BookingDetailsState(booking: current.booking, isCancelling: true),
    );
    try {
      final booking = await ref.read(bookingRepositoryProvider).cancel(arg);
      ref.invalidate(bookingsProvider);
      state = AsyncData(BookingDetailsState(booking: booking));
    } on ApiException catch (failure) {
      state = AsyncData(
        BookingDetailsState(booking: current.booking, cancelFailure: failure),
      );
    }
  }
}
