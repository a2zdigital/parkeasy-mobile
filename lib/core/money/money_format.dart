import 'package:app/core/money/money.dart';

/// Formats money for display, exactly: the digits are taken from the
/// decimal value and never pass through a `double`.
///
/// Rupees use the rupee sign and Indian grouping (`₹1,25,000.00`). Any
/// other currency is shown with its code (`USD 1,250.00`).
///
/// With [compact], a whole amount drops its decimals (`₹40`); used where
/// space is tight and the unit follows, as in "₹40 / hour".
String formatMoney(Money money, {bool compact = false}) {
  final fixed = money.amount.toStringAsFixed(2);
  final negative = fixed.startsWith('-');
  final parts = (negative ? fixed.substring(1) : fixed).split('.');
  final isRupee = money.currency == 'INR';

  final whole = isRupee ? _groupIndian(parts[0]) : _groupThousands(parts[0]);
  final decimals = compact && parts[1] == '00' ? '' : '.${parts[1]}';
  final symbol = isRupee ? '₹' : '${money.currency} ';

  return '${negative ? '-' : ''}$symbol$whole$decimals';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Indian grouping: the last three digits, then pairs.
String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;

  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final buffer = StringBuffer();
  for (var i = 0; i < head.length; i++) {
    if (i > 0 && (head.length - i).isEven) buffer.write(',');
    buffer.write(head[i]);
  }
  return '$buffer,$tail';
}
