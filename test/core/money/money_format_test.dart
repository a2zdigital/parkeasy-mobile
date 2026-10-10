import 'package:app/core/money/money.dart';
import 'package:app/core/money/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String rupees(String amount, {bool compact = false}) =>
      formatMoney(Money.parse(amount, 'INR'), compact: compact);

  test('rupees use the sign, two decimals and Indian grouping', () {
    expect(rupees('0.00'), '₹0.00');
    expect(rupees('40'), '₹40.00');
    expect(rupees('999.5'), '₹999.50');
    expect(rupees('1000'), '₹1,000.00');
    expect(rupees('12500'), '₹12,500.00');
    expect(rupees('125000'), '₹1,25,000.00');
    expect(rupees('1250000.75'), '₹12,50,000.75');
    expect(rupees('123456789'), '₹12,34,56,789.00');
  });

  test('compact drops the decimals of a whole amount only', () {
    expect(rupees('40.00', compact: true), '₹40');
    expect(rupees('40.50', compact: true), '₹40.50');
    expect(rupees('125000', compact: true), '₹1,25,000');
  });

  test('large amounts stay exact', () {
    expect(rupees('999999999999.99'), '₹9,99,99,99,99,999.99');
  });

  test('negative amounts keep the sign in front', () {
    expect(rupees('-80.00'), '-₹80.00');
  });

  test('another currency shows its code and groups by thousands', () {
    expect(formatMoney(Money.parse('1250000.5', 'USD')), 'USD 1,250,000.50');
  });
}
