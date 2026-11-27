import 'package:flutter/services.dart';

/// The two identity cards an owner sends: Aadhaar and PAN.
enum IdentityCardKind {
  aadhaar('aadhaar'),
  pan('pan');

  const IdentityCardKind(this.wire);

  /// The value the API expects in `identity_kind`.
  final String wire;
}

/// Format checks for Indian identity numbers, the same as the server's.
///
/// A number that passes is typed correctly, nothing more: whether it is
/// genuine is checked by the server's identity verification service.
abstract final class IdentityNumbers {
  static const _panHolderTypes = 'ABCFGHJLPT';

  static const _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  static const _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 8, 7, 0, 6],
    [4, 2, 8, 0, 5, 7, 1, 3, 6, 9],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  /// The digits of an Aadhaar number, ignoring spaces and hyphens.
  static String aadhaarDigits(String value) =>
      value.replaceAll(RegExp(r'[\s-]'), '');

  /// 12 digits, not starting with 0 or 1, with a valid Verhoeff check digit.
  static bool isValidAadhaar(String value) {
    final digits = aadhaarDigits(value);
    if (!RegExp(r'^[2-9]\d{11}$').hasMatch(digits)) return false;
    var check = 0;
    final reversed = digits.split('').reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      check = _d[check][_p[i % 8][int.parse(reversed[i])]];
    }
    return check == 0;
  }

  static String normalisePan(String value) =>
      value.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// 5 letters (the 4th a holder type, P for a person), 4 digits, 1 letter.
  static bool isValidPan(String value) {
    final pan = normalisePan(value);
    return RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(pan) &&
        _panHolderTypes.contains(pan[3]);
  }

  static bool isValid(IdentityCardKind kind, String value) => switch (kind) {
    IdentityCardKind.aadhaar => isValidAadhaar(value),
    IdentityCardKind.pan => isValidPan(value),
  };

  /// Whether a stored number is this kind of card (an Aadhaar is stored masked).
  static bool isStoredAs(IdentityCardKind kind, String? stored) {
    if (stored == null) return false;
    return switch (kind) {
      IdentityCardKind.aadhaar =>
        RegExp(r'^XXXX XXXX \d{4}$').hasMatch(stored.trim()) ||
            isValidAadhaar(stored),
      IdentityCardKind.pan => isValidPan(stored),
    };
  }

  /// What the owner types, shaped as they type: "1234 5678 9012" or "ABCDE1234F".
  static TextInputFormatter formatter(IdentityCardKind kind) => switch (kind) {
    IdentityCardKind.aadhaar => const _AadhaarFormatter(),
    IdentityCardKind.pan => const _PanFormatter(),
  };
}

class _AadhaarFormatter extends TextInputFormatter {
  const _AadhaarFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 12 ? digits.substring(0, 12) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PanFormatter extends TextInputFormatter {
  const _PanFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    final text = cleaned.length > 10 ? cleaned.substring(0, 10) : cleaned;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
