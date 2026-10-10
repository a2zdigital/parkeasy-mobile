/// Indian mobile numbers: the pilot's only market.
abstract final class PhoneNumber {
  static const String countryCode = '+91';
  static const int nationalLength = 10;

  static final RegExp _national = RegExp(r'^[6-9]\d{9}$');

  /// The E.164 number for what the user typed, or null when it is not a
  /// valid mobile number. Spaces and a leading country code are accepted.
  static String? toE164(String input) {
    var digits = input.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith(countryCode)) {
      digits = digits.substring(countryCode.length);
    }
    return _national.hasMatch(digits) ? '$countryCode$digits' : null;
  }

  /// For display: `+91 90000 00001`.
  static String format(String e164) {
    if (!e164.startsWith(countryCode) ||
        e164.length != countryCode.length + nationalLength) {
      return e164;
    }
    final national = e164.substring(countryCode.length);
    return '$countryCode ${national.substring(0, 5)} ${national.substring(5)}';
  }
}
