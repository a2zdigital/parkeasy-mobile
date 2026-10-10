import 'package:app/features/payment/data/models/payment_order.dart';

/// The contents of an order's `checkout` object, read defensively: it is
/// free-form JSON whose shape belongs to the payment provider.
class CheckoutDetails {
  const CheckoutDetails({
    required this.provider,
    required this.orderId,
    required this.amountMinor,
    required this.currency,
    this.keyId,
    this.name,
    this.description,
  });

  /// The simulated provider used by development and test servers.
  static const String fakeProvider = 'fake';

  final String provider;
  final String orderId;
  final int amountMinor;
  final String currency;

  /// The provider's public key ID. Absent for the simulated provider.
  final String? keyId;
  final String? name;
  final String? description;

  bool get isSimulated => provider == fakeProvider;

  /// Null when the order can no longer be paid, or the object is not in a
  /// shape this build understands.
  static CheckoutDetails? of(PaymentOrder order) {
    final checkout = order.checkout;
    if (checkout == null) return null;

    final provider = checkout['provider'];
    final orderId = checkout['order_id'];
    final amount = checkout['amount_minor'];
    final currency = checkout['currency'];
    if (provider is! String ||
        orderId is! String ||
        orderId.isEmpty ||
        amount is! int ||
        amount <= 0 ||
        currency is! String) {
      return null;
    }

    String? text(String key) {
      final value = checkout[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return CheckoutDetails(
      provider: provider,
      orderId: orderId,
      amountMinor: amount,
      currency: currency,
      keyId: text('key_id'),
      name: text('name'),
      description: text('description'),
    );
  }
}
