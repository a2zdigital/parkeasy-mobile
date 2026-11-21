import 'dart:async';

import 'package:app/core/payment/checkout_launcher.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Razorpay's standard checkout. The only file that imports the SDK.
class RazorpayCheckoutLauncher implements CheckoutLauncher {
  @override
  Future<CheckoutResult> open(CheckoutRequest request) {
    final razorpay = Razorpay();
    final result = Completer<CheckoutResult>();

    void finish(CheckoutOutcome outcome, {CheckoutReceipt? receipt}) {
      if (result.isCompleted) return;
      razorpay.clear();
      result.complete(CheckoutResult(outcome, receipt: receipt));
    }

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        final orderId = response.orderId;
        final paymentId = response.paymentId;
        final signature = response.signature;
        finish(
          CheckoutOutcome.completed,
          receipt: orderId == null || paymentId == null || signature == null
              ? null
              : CheckoutReceipt(
                  orderId: orderId,
                  paymentId: paymentId,
                  signature: signature,
                ),
        );
      })
      ..on(
        Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) => finish(
          response.code == Razorpay.PAYMENT_CANCELLED
              ? CheckoutOutcome.dismissed
              : CheckoutOutcome.failed,
        ),
      )
      // Paying with an external wallet leaves the window; the result
      // arrives at our API like any other.
      ..on(
        Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse _) => finish(CheckoutOutcome.completed),
      );

    final brand = AppColors.light.primary.toARGB32() & 0xFFFFFF;
    final contact = request.contact;

    try {
      razorpay.open({
        'key': request.keyId,
        'order_id': request.orderId,
        'amount': request.amountMinor,
        'currency': request.currency,
        'name': request.name,
        'description': request.description,
        'theme': {'color': '#${brand.toRadixString(16).padLeft(6, '0')}'},
        'retry': {'enabled': false},
        if (contact != null) 'prefill': {'contact': contact},
      });
    } on Object {
      finish(CheckoutOutcome.failed);
    }

    return result.future;
  }
}
