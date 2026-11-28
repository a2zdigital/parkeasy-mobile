/// How extra time was paid at the gate.
enum ExtraTimeMethod {
  cash('cash'),
  upi('upi'),
  card('card');

  const ExtraTimeMethod(this.wire);

  final String wire;
}

/// What the person at the gate confirmed: how extra time was paid (when
/// any is due) and the amount they were shown, which the API checks again.
class CheckOutChoice {
  const CheckOutChoice({
    this.method,
    this.expectedAmount,
    this.bookingMethod,
    this.bookingAmount,
  });

  final ExtraTimeMethod? method;
  final String? expectedAmount;

  /// How the booking's own amount was paid at the facility, when it was
  /// due there and the person confirmed they received it.
  final ExtraTimeMethod? bookingMethod;

  /// The booking amount they were shown and collected; the API checks it
  /// against the amount outstanding.
  final String? bookingAmount;

  /// The check-out request's payment fields.
  Map<String, Object?> toJson() => {
    if (method case final m?) 'extra_time_payment_method': m.wire,
    if (expectedAmount case final a?) 'expected_extra_time_amount': a,
    if (bookingMethod case final m?) ...{
      'booking_payment_method': m.wire,
      'booking_payment_collected': true,
      'booking_payment_amount': ?bookingAmount,
    },
  };
}
