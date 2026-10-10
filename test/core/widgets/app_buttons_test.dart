import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('PrimaryButton calls back when pressed', (tester) async {
    var presses = 0;
    await pump(
      tester,
      PrimaryButton(label: 'Book', onPressed: () => presses++),
    );

    await tester.tap(find.text('Book'));

    expect(presses, 1);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      AppSize.primaryButtonHeight,
    );
  });

  testWidgets(
    'while loading it shows progress, ignores presses and keeps its size',
    (tester) async {
      var presses = 0;
      await pump(
        tester,
        PrimaryButton(label: 'Book', onPressed: () => presses++),
      );
      final idle = tester.getSize(find.byType(FilledButton));

      await pump(
        tester,
        PrimaryButton(
          label: 'Book',
          isLoading: true,
          onPressed: () => presses++,
        ),
      );
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);

      expect(presses, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), idle);
    },
  );

  testWidgets('every button meets the minimum touch target', (tester) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: 'A', onPressed: () {}),
          SecondaryButton(label: 'B', onPressed: () {}),
          TextAction(label: 'C', onPressed: () {}),
        ],
      ),
    );

    for (final type in [FilledButton, OutlinedButton, TextButton]) {
      expect(
        tester.getSize(find.byType(type)).height,
        greaterThanOrEqualTo(AppSize.touchTarget),
        reason: '$type',
      );
    }
  });

  testWidgets('a long label at double text size does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: PrimaryButton(
                  label: 'Pay ₹1,25,000.00 and confirm the booking',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
