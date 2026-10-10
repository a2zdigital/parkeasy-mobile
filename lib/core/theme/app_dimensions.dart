import 'package:flutter/widgets.dart';

/// Spacing on a 4-point grid. Values: docs/design/tokens.md.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Fixed sizes of the layout.
abstract final class AppSize {
  static const double screenPadding = 20;
  static const double screenPaddingCompact = 16;

  /// Below this width the compact screen padding is used.
  static const double compactWidth = 360;

  static const double touchTarget = 48;
  static const double primaryButtonHeight = 52;
  static const double controlHeight = 48;
  static const double inputHeight = 52;
  static const double icon = 24;
  static const double iconSmall = 20;
  static const double spinner = 20;
  static const double borderWidth = 1;
  static const double focusBorderWidth = 2;
}

/// Corner radii.
abstract final class AppRadius {
  static const double small = 8;
  static const double control = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius controlAll = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Durations and curves. Motion explains a change of state, nothing else.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
}

/// Empty space of a token size, between children of a row or column.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  const Gap.xs({super.key}) : size = AppSpace.xs;
  const Gap.sm({super.key}) : size = AppSpace.sm;
  const Gap.md({super.key}) : size = AppSpace.md;
  const Gap.lg({super.key}) : size = AppSpace.lg;
  const Gap.xl({super.key}) : size = AppSpace.xl;
  const Gap.xxl({super.key}) : size = AppSpace.xxl;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size);
}
