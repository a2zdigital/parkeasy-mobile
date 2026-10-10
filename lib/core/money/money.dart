import 'package:decimal/decimal.dart';

/// An amount of money in one currency, exactly as the API sent it.
///
/// The app shows and compares money; it never calculates a price. There is
/// deliberately no arithmetic here: totals come from a quote or a booking.
class Money implements Comparable<Money> {
  Money(this.amount, this.currency)
    : assert(currency.length == 3, 'Currency is a three-letter ISO code.');

  /// Parses the API's decimal string, for example `"80.00"`.
  ///
  /// Throws a [FormatException] for anything that is not a plain decimal
  /// with at most two places.
  factory Money.parse(String amount, String currency) {
    if (!_pattern.hasMatch(amount)) {
      throw FormatException('Not a money amount', amount);
    }
    return Money(Decimal.parse(amount), currency);
  }

  static final RegExp _pattern = RegExp(r'^-?\d{1,12}(\.\d{1,2})?$');

  final Decimal amount;

  /// ISO 4217 code, for example `INR`.
  final String currency;

  bool get isZero => amount == Decimal.zero;

  /// The form the API accepts: two decimal places, no symbol.
  String toWire() => amount.toStringAsFixed(2);

  @override
  int compareTo(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Cannot compare $currency with ${other.currency}.');
    }
    return amount.compareTo(other.amount);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '$currency ${toWire()}';
}
