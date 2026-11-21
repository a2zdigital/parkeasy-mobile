import 'package:app/core/money/money.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/booking/data/models/charge_line.dart';
import 'package:app/features/booking/data/models/price_line.dart';
import 'package:app/features/booking/data/models/quote.dart';
import 'package:app/features/booking/ui/price_breakdown.dart';
import 'package:app/features/owner/data/models/gst_registration.dart';
import 'package:app/features/parking_lot/data/models/rate_type.dart';
import 'package:app/l10n/l10n.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  final hours = PriceLine(
    rateType: RateType.hourly,
    quantity: 2,
    unitAmount: Decimal.parse('40.00'),
    amount: Decimal.parse('80.00'),
  );

  testWidgets('shows the parking charge and each GST line when GST applies', (
    tester,
  ) async {
    await pump(
      tester,
      PriceBreakdown(
        lines: [hours],
        total: Money(Decimal.parse('94.40'), 'INR'),
        charges: [
          ChargeLine(code: 'parking', amount: Decimal.parse('80.00')),
          ChargeLine(
            code: 'parking_cgst',
            rate: '9',
            amount: Decimal.parse('7.20'),
          ),
          ChargeLine(
            code: 'parking_sgst',
            rate: '9',
            amount: Decimal.parse('7.20'),
          ),
        ],
      ),
    );

    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('CGST 9%'), findsOneWidget);
    expect(find.text('SGST 9%'), findsOneWidget);
    expect(find.textContaining('94.40'), findsOneWidget);
  });

  testWidgets('without GST it looks as before', (tester) async {
    await pump(
      tester,
      PriceBreakdown(
        lines: [hours],
        total: Money(Decimal.parse('80.00'), 'INR'),
        charges: [ChargeLine(code: 'parking', amount: Decimal.parse('80.00'))],
      ),
    );

    expect(find.text('Parking'), findsNothing);
    expect(find.textContaining('CGST'), findsNothing);
  });

  test('a quote reads its charges, and older quotes have none', () {
    final base = {
      'parking_lot_id': '01M4JQSZSNAVTVCMS8A7AJ0WJ9',
      'vehicle_type': 'car',
      'start_at': '2026-11-02T04:30:00Z',
      'end_at': '2026-11-02T06:30:00Z',
      'timezone': 'Asia/Kolkata',
      'booking_mode': 'instant',
      'base_amount': '80.00',
      'total_amount': '94.40',
      'currency': 'INR',
    };
    final quote = Quote.fromJson({
      ...base,
      'charges': [
        {'code': 'parking', 'rate': null, 'amount': '80.00'},
        {'code': 'parking_igst', 'rate': '18', 'amount': '14.40'},
      ],
    });

    expect(quote.charges.map((c) => c.taxName).last, 'IGST');
    expect(quote.charges.last.isTax, isTrue);
    expect(Quote.fromJson(base).charges, isEmpty);
  });

  test('GSTIN shape check', () {
    expect(gstinPattern.hasMatch('29ABCDE1234F1Z5'), isTrue);
    expect(gstinPattern.hasMatch('29abcde1234f1z5'), isFalse);
    expect(gstinPattern.hasMatch('29ABCDE1234F1X5'), isFalse);
  });
}
