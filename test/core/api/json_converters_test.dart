import 'package:app/core/api/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UtcDateTimeConverter', () {
    const converter = UtcDateTimeConverter();

    test('reads a UTC timestamp as UTC', () {
      final value = converter.fromJson('2026-11-02T04:30:00Z');

      expect(value.isUtc, isTrue);
      expect(value, DateTime.utc(2026, 11, 2, 4, 30));
    });

    test('converts a timestamp with an offset to UTC', () {
      expect(
        converter.fromJson('2026-11-02T10:00:00+05:30'),
        DateTime.utc(2026, 11, 2, 4, 30),
      );
    });

    test('writes UTC with Z and no fraction, even from local time', () {
      expect(
        converter.toJson(DateTime.utc(2026, 1, 5, 9, 7, 3, 250)),
        '2026-01-05T09:07:03Z',
      );
      final local = DateTime.utc(2026, 11, 2, 4, 30).toLocal();
      expect(converter.toJson(local), '2026-11-02T04:30:00Z');
    });
  });

  test('MoneyAmountConverter writes two decimals', () {
    const converter = MoneyAmountConverter();

    expect(converter.fromJson('80.00'), Decimal.parse('80'));
    expect(converter.toJson(Decimal.parse('80')), '80.00');
    expect(converter.toJson(Decimal.parse('0.5')), '0.50');
  });

  test('DecimalConverter keeps the value as written', () {
    const converter = DecimalConverter();

    expect(converter.toJson(converter.fromJson('15')), '15');
    expect(converter.toJson(converter.fromJson('12.5')), '12.5');
  });

  test('FlexibleDoubleConverter accepts a number or a numeric string', () {
    const converter = FlexibleDoubleConverter();

    expect(converter.fromJson(12.9756), 12.9756);
    expect(converter.fromJson(13), 13.0);
    expect(converter.fromJson('77.6050'), 77.605);
    expect(() => converter.fromJson(true), throwsFormatException);
  });

  test('JsonObjectConverter reads an empty PHP array as an empty object', () {
    const converter = JsonObjectConverter();

    expect(converter.fromJson({'booking_id': 'b1'}), {'booking_id': 'b1'});
    expect(converter.fromJson(<Object?>[]), isEmpty);
    expect(converter.fromJson(null), isEmpty);
  });
}
