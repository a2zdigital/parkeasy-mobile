import 'package:app/core/validation/identity_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aadhaar', () {
    test(
      'accepts a number with a valid check digit, with or without spaces',
      () {
        expect(IdentityNumbers.isValidAadhaar('234123412346'), isTrue);
        expect(IdentityNumbers.isValidAadhaar('2341 2341 2346'), isTrue);
      },
    );

    test(
      'refuses a wrong check digit, a short number or one starting with 0 or 1',
      () {
        expect(IdentityNumbers.isValidAadhaar('234123412345'), isFalse);
        expect(IdentityNumbers.isValidAadhaar('23412341'), isFalse);
        expect(IdentityNumbers.isValidAadhaar('123412341234'), isFalse);
      },
    );

    test('is typed in groups of four, digits only, at most 12', () {
      final formatter = IdentityNumbers.formatter(IdentityCardKind.aadhaar);
      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2341a23412346999'),
      );
      expect(value.text, '2341 2341 2346');
    });

    test('a stored masked number counts as the Aadhaar card', () {
      expect(
        IdentityNumbers.isStoredAs(IdentityCardKind.aadhaar, 'XXXX XXXX 2346'),
        isTrue,
      );
      expect(
        IdentityNumbers.isStoredAs(IdentityCardKind.pan, 'XXXX XXXX 2346'),
        isFalse,
      );
    });
  });

  group('PAN', () {
    test('accepts 5 letters, 4 digits and a letter, in any case', () {
      expect(IdentityNumbers.isValidPan('ABCPE1234F'), isTrue);
      expect(IdentityNumbers.isValidPan('abcpe1234f'), isTrue);
    });

    test('refuses other shapes and unknown holder types', () {
      expect(IdentityNumbers.isValidPan('ABC1234567'), isFalse);
      expect(IdentityNumbers.isValidPan('ABCXE1234F'), isFalse);
    });

    test('is typed in capitals, letters and digits only, at most 10', () {
      final formatter = IdentityNumbers.formatter(IdentityCardKind.pan);
      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abc pe-1234fzz'),
      );
      expect(value.text, 'ABCPE1234F');
    });
  });
}
