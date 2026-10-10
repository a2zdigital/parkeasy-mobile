import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/app_identity.dart';
import 'package:app/core/payment/checkout_launcher.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:app/features/booking/state/booking_details_notifier.dart';
import 'package:app/features/booking/state/bookings_notifier.dart';
import 'package:app/features/booking/state/create_booking_notifier.dart';
import 'package:app/features/payment/data/models/checkout_details.dart';
import 'package:app/features/payment/data/models/payment_order.dart';
import 'package:app/features/payment/data/models/payment_order_status.dart';
import 'package:app/features/payment/data/payment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentProvider = NotifierProvider.autoDispose
    .family<PaymentNotifier, PaymentState, String>(PaymentNotifier.new);

/// Waits between checks of the payment's status. Overridden in tests so
/// they do not wait in real time.
final pollDelayProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

enum PaymentStage {
  /// Asking the API for an order.
  starting,

  /// A test server: the tester chooses the outcome.
  readyToSimulate,

  /// The provider's window is open.
  inCheckout,

  /// Asking the API whether the money arrived.
  confirming,

  /// The API confirmed the payment.
  succeeded,

  /// The API reported the payment failed.
  failed,

  /// The window was closed without paying.
  notCompleted,

  /// The window reported success but the API has not confirmed in time.
  /// The payment may still arrive; the user must not pay again.
  stillPending,

  /// The order cannot be paid by this build.
  unavailable,

  /// The API refused to start or check the payment; see `failure`.
  refused,
}

class PaymentState {
  const PaymentState({required this.stage, this.order, this.failure});

  final PaymentStage stage;
  final PaymentOrder? order;
  final ApiException? failure;
}

/// Takes one booking through paying online.
///
/// The rule this class exists to keep: **a payment has succeeded only
/// when our API says so.** The provider's window can report success for a
/// payment that never settles, and can be closed after a payment that
/// did. So whatever the window says, the API is asked.
class PaymentNotifier extends AutoDisposeFamilyNotifier<PaymentState, String> {
  static const Duration pollInterval = Duration(seconds: 2);

  /// About a minute of checking after the window reports success.
  static const int confirmAttempts = 30;

  String? _key;
  bool _disposed = false;

  @override
  PaymentState build(String arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() {
      if (!_disposed) start();
    });
    return const PaymentState(stage: PaymentStage.starting);
  }

  /// Creates the order and opens the way to pay it. Also "Try again".
  Future<void> start() async {
    _set(const PaymentState(stage: PaymentStage.starting));

    final PaymentOrder order;
    try {
      order = await ref
          .read(paymentRepositoryProvider)
          .createOrder(
            arg,
            idempotencyKey: _key ??= ref.read(idempotencyKeyFactoryProvider)(),
          );
      _key = null;
    } on ApiException catch (failure) {
      if (!failure.isTransient) _key = null;
      if (failure.code == ApiErrorCode.paymentAlreadyCompleted) {
        _succeeded(null);
      } else {
        _set(PaymentState(stage: PaymentStage.refused, failure: failure));
      }
      return;
    }
    if (_disposed) return;

    if (order.status == PaymentOrderStatus.succeeded) {
      _succeeded(order);
      return;
    }

    final details = CheckoutDetails.of(order);
    if (details == null) {
      _set(PaymentState(stage: PaymentStage.unavailable, order: order));
      return;
    }

    if (details.isSimulated) {
      _set(
        PaymentState(
          stage: ref.read(appConfigProvider).enablePaymentSimulation
              ? PaymentStage.readyToSimulate
              : PaymentStage.unavailable,
          order: order,
        ),
      );
      return;
    }

    final keyId = details.keyId;
    if (keyId == null) {
      _set(PaymentState(stage: PaymentStage.unavailable, order: order));
      return;
    }

    _set(PaymentState(stage: PaymentStage.inCheckout, order: order));
    final session = ref.read(sessionControllerProvider);
    final outcome = await ref
        .read(checkoutLauncherProvider)
        .open(
          CheckoutRequest(
            keyId: keyId,
            orderId: details.orderId,
            amountMinor: details.amountMinor,
            currency: details.currency,
            name: details.name ?? appDisplayName,
            description: details.description ?? '',
            contact: session is SignedIn ? session.user.phone : null,
          ),
        );
    if (_disposed) return;

    switch (outcome) {
      case CheckoutOutcome.completed:
        await _confirm(order, confirmAttempts, PaymentStage.stillPending);
      case CheckoutOutcome.dismissed:
        // Closing the window does not prove nothing was paid: check once.
        await _confirm(order, 1, PaymentStage.notCompleted);
      case CheckoutOutcome.failed:
        await _confirm(order, 1, PaymentStage.failed);
    }
  }

  /// Test servers only: let the tester decide how the payment ends.
  Future<void> simulate({required bool succeed}) async {
    final order = state.order;
    if (state.stage != PaymentStage.readyToSimulate || order == null) return;

    _set(PaymentState(stage: PaymentStage.confirming, order: order));
    try {
      await ref.read(paymentRepositoryProvider).simulate(arg, succeed: succeed);
    } on ApiException catch (failure) {
      _set(
        PaymentState(
          stage: PaymentStage.refused,
          order: order,
          failure: failure,
        ),
      );
      return;
    }
    await _confirm(order, confirmAttempts, PaymentStage.stillPending);
  }

  /// Asks the API up to [attempts] times whether the payment arrived, and
  /// ends in [otherwise] if it gives no definite answer.
  Future<void> _confirm(
    PaymentOrder order,
    int attempts,
    PaymentStage otherwise,
  ) async {
    _set(PaymentState(stage: PaymentStage.confirming, order: order));
    final repository = ref.read(paymentRepositoryProvider);
    final wait = ref.read(pollDelayProvider);

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final payment = await repository.status(arg);
        if (_disposed) return;

        final latest = payment.order;
        if (latest?.status == PaymentOrderStatus.succeeded ||
            payment.bookingStatus == BookingStatus.confirmed) {
          _succeeded(latest ?? order);
          return;
        }
        if (latest?.status == PaymentOrderStatus.failed) {
          _set(PaymentState(stage: PaymentStage.failed, order: latest));
          return;
        }
      } on ApiException {
        // A lost connection while checking is not an answer: keep asking.
        if (_disposed) return;
      }

      if (attempt < attempts) {
        await wait(pollInterval);
        if (_disposed) return;
      }
    }

    _set(PaymentState(stage: otherwise, order: order));
  }

  void _succeeded(PaymentOrder? order) {
    if (_disposed) return;
    // The booking changed on the server: let its screens reload.
    ref
      ..invalidate(bookingDetailsProvider(arg))
      ..invalidate(bookingsProvider);
    state = PaymentState(stage: PaymentStage.succeeded, order: order);
  }

  void _set(PaymentState next) {
    if (!_disposed) state = next;
  }
}
