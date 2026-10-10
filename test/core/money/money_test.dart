import 'package:app/core/money/money.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('parses the decimal string the API sends', () {
      final money = Money.parse('80.00', 'INR');

      expect(money.amount, Decimal.parse('80'));
      expect(money.currency, 'INR');
      expect(money.toWire(), '80.00');
    });

    test('keeps amounts a double cannot hold exactly', () {
      expect(Money.parse('0.10', 'INR').toWire(), '0.10');
      expect(Money.parse('1234567890.99', 'INR').toWire(), '1234567890.99');
    });

    test('rejects anything that is not a plain decimal', () {
      for (final bad in [
        '',
        'abc',
        '1,250.00',
        '80.001',
        '₹80',
        '1e3',
        ' 80',
      ]) {
        expect(
          () => Money.parse(bad, 'INR'),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('equal when amount and currency are equal', () {
      expect(Money.parse('80', 'INR'), Money.parse('80.00', 'INR'));
      expect(
        Money.parse('80', 'INR').hashCode,
        Money.parse('80.00', 'INR').hashCode,
      );
      expect(Money.parse('80.00', 'INR'), isNot(Money.parse('80.00', 'USD')));
    });

    test('compares within a currency and refuses across currencies', () {
      final low = Money.parse('40.00', 'INR');
      final high = Money.parse('250.00', 'INR');

      expect(low.compareTo(high), lessThan(0));
      expect(
        () => low.compareTo(Money.parse('1.00', 'USD')),
        throwsArgumentError,
      );
    });

    test('knows when it is zero', () {
      expect(Money.parse('0.00', 'INR').isZero, isTrue);
      expect(Money.parse('0.01', 'INR').isZero, isFalse);
    });
  });
}
