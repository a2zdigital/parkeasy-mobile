/// What the payment window reported when it closed.
///
/// **None of these is proof of payment.** Even [completed] only means the
/// window says so; the booking is confirmed solely by our API, which hears
/// from the payment provider directly. The outcome decides only how long
/// the app waits for that confirmation.
enum CheckoutOutcome { completed, dismissed, failed }

/// Everything the payment window needs. All of it comes from our API with
/// the order; nothing here is stored in the app.
class CheckoutRequest {
  const CheckoutRequest({
    required this.keyId,
    required this.orderId,
    required this.amountMinor,
    required this.currency,
    required this.name,
    required this.description,
    this.contact,
  });

  /// The provider's **public** key ID. The key secret never leaves the
  /// server.
  final String keyId;
  final String orderId;

  /// Amount in the smallest unit (paise).
  final int amountMinor;
  final String currency;

  /// The merchant name shown in the window.
  final String name;
  final String description;

  /// The payer's phone number, to save them typing it.
  final String? contact;
}

/// Opens a payment provider's checkout. The provider's SDK is used only
/// behind this interface, so no feature imports it and tests never touch it.
abstract interface class CheckoutLauncher {
  Future<CheckoutOutcome> open(CheckoutRequest request);
}
