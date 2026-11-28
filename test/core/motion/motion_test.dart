import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The motion layer: it plays once, ends exactly where the content belongs,
/// and steps aside when the device asks for reduced motion.
void main() {
  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  double opacityOf(WidgetTester tester, Finder content) => tester
      .widget<Opacity>(
        find.ancestor(of: content, matching: find.byType(Opacity)).first,
      )
      .opacity;

  group('FadeSlideIn', () {
    testWidgets('fades in once and ends fully visible', (tester) async {
      await tester.pumpWidget(host(const FadeSlideIn(child: Text('Item'))));
      expect(opacityOf(tester, find.text('Item')), 0);

      await tester.pump(AppMotion.slow ~/ 2);
      final halfway = opacityOf(tester, find.text('Item'));
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(1));

      await tester.pumpAndSettle();
      expect(opacityOf(tester, find.text('Item')), 1);
    });

    testWidgets('a later item waits a little, a long list does not', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              FadeSlideIn(child: Text('First')),
              FadeSlideIn(index: 3, child: Text('Fourth')),
            ],
          ),
        ),
      );
      await tester.pump(FadeSlideIn.step * 2);
      expect(opacityOf(tester, find.text('First')), greaterThan(0));
      expect(opacityOf(tester, find.text('Fourth')), 0);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, find.text('Fourth')), 1);
    });

    testWidgets('with reduced motion it is there at once', (tester) async {
      await tester.pumpWidget(
        host(const FadeSlideIn(index: 5, child: Text('Item')), reduced: true),
      );
      await tester.pump();
      expect(opacityOf(tester, find.text('Item')), 1);
    });
  });

  group('Reveal', () {
    testWidgets('grows into place and ends at full size', (tester) async {
      await tester.pumpWidget(host(const Reveal(child: Text('Code'))));
      await tester.pumpAndSettle();
      final scale = tester.widget<Transform>(
        find
            .ancestor(of: find.text('Code'), matching: find.byType(Transform))
            .first,
      );
      expect(scale.transform.getMaxScaleOnAxis(), closeTo(1, 0.0001));
      expect(opacityOf(tester, find.text('Code')), 1);
    });

    testWidgets('with reduced motion it is not animated', (tester) async {
      await tester.pumpWidget(
        host(const Reveal(child: Text('Code')), reduced: true),
      );
      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('CountUpText', () {
    String rupees(double value) => '₹${value.toStringAsFixed(2)}';

    testWidgets('counts up and lands on the exact text', (tester) async {
      await tester.pumpWidget(host(CountUpText(value: 1250, format: rupees)));
      expect(find.text('₹0.00'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('₹1250.00'), findsOneWidget);
    });

    testWidgets('screen readers get the final figure, not the counting', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(CountUpText(value: 1250, format: rupees)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('₹1250.00'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('with reduced motion the final figure shows at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(CountUpText(value: 1250, format: rupees), reduced: true),
      );
      expect(find.text('₹1250.00'), findsOneWidget);
    });
  });

  group('PressScale', () {
    testWidgets('shrinks slightly while pressed, then returns', (tester) async {
      await tester.pumpWidget(
        host(
          const PressScale(
            child: SizedBox(width: 100, height: 40, child: Text('Card')),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Card')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.98,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('does nothing with reduced motion or when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const PressScale(child: Text('Card')), reduced: true),
      );
      expect(find.byType(AnimatedScale), findsNothing);

      await tester.pumpWidget(
        host(const PressScale(enabled: false, child: Text('Card'))),
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });

  group('page transitions', () {
    Widget app({required bool reduced}) => MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: AppPageTransitionsBuilder()},
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const Text('Next page')),
          ),
          child: const Text('Open'),
        ),
      ),
    );

    testWidgets('a new page fades and rises in', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(app(reduced: false));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(AppMotion.slow ~/ 2);
      expect(
        find.ancestor(
          of: find.text('Next page'),
          matching: find.byType(SlideTransition),
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(find.text('Next page'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('with reduced motion it only fades', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(app(reduced: true));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(AppMotion.slow ~/ 2);
      final slides = find.ancestor(
        of: find.text('Next page'),
        matching: find.byType(SlideTransition),
      );
      expect(slides, findsNothing);
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
