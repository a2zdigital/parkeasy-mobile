import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/idempotency_key.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/create_booking_request.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/booking/state/booking_draft.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final createBookingProvider = NotifierProvider.autoDispose
    .family<CreateBookingNotifier, CreateBookingState, BookingDraft>(
      CreateBookingNotifier.new,
    );

/// Makes idempotency keys. Overridden in tests to make them predictable.
final idempotencyKeyFactoryProvider = Provider<String Function()>(
  (ref) => newIdempotencyKey,
);

class CreateBookingState {
  const CreateBookingState({
    required this.paymentMode,
    this.isSubmitting = false,
    this.failure,
    this.created,
  });

  final PaymentMode paymentMode;
  final bool isSubmitting;
  final ApiException? failure;

  /// Set once when the booking exists; the screen moves to it.
  final Booking? created;
}

class CreateBookingNotifier
    extends AutoDisposeFamilyNotifier<CreateBookingState, BookingDraft> {
  // One key per attempt to book. It is kept while the outcome is unknown
  // (no answer, a timeout, "still in progress") so that pressing again
  // repeats the same request instead of making a second booking. A
  // definite answer, or a change to what is being booked, ends it.
  String? _key;

  @override
  CreateBookingState build(BookingDraft arg) => CreateBookingState(
    // Paying at the facility is offered first where both are accepted.
    paymentMode: arg.quote.acceptsOnsitePayment
        ? PaymentMode.onSite
        : PaymentMode.online,
  );

  void selectPaymentMode(PaymentMode mode) {
    if (state.isSubmitting || mode == state.paymentMode) return;

    _key = null; // A different request needs a different key.
    state = CreateBookingState(paymentMode: mode);
  }

  Future<void> submit() async {
    if (state.isSubmitting || state.created != null) return;

    final key = _key ??= ref.read(idempotencyKeyFactoryProvider)();
    state = CreateBookingState(
      paymentMode: state.paymentMode,
      isSubmitting: true,
    );

    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .create(
            CreateBookingRequest(
              parkingLotId: arg.lot.id,
              vehicleType: arg.vehicleType,
              startAt: arg.startAt,
              endAt: arg.endAt,
              paymentMode: state.paymentMode,
              // The price the customer saw. The API refuses with
              // QUOTE_EXPIRED if it no longer matches; it never trusts it.
              expectedTotalAmount: arg.quote.totalAmount,
            ),
            idempotencyKey: key,
          );
      _key = null;
      ref.invalidate(bookingsProvider);
      state = CreateBookingState(
        paymentMode: state.paymentMode,
        created: booking,
      );
    } on ApiException catch (failure) {
      if (!failure.isTransient) {
        _key = null;
      }
      state = CreateBookingState(
        paymentMode: state.paymentMode,
        failure: failure,
      );
    }
  }
}
