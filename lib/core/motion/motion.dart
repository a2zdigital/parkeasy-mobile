import 'package:app/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Motion that explains a change of state: something arrived, was pressed,
/// was revealed or moved. All of it uses [AppMotion] durations, plays once
/// (never loops), and turns off when the device asks for reduced motion
/// (Settings > Accessibility > Remove animations on Android, Reduce Motion
/// on iOS): content then simply appears, and page changes become fades.
///
/// Rules: docs/design/tokens.md (Motion).
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Content that fades and rises into place once, the first time it is
/// built. In a list, [index] staggers the items a little (the first few
/// only, so a long list never waits).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  /// Items after this many start together.
  static const int maxStagger = 6;
  static const Duration step = Duration(milliseconds: 40);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    // The stagger is part of the animation itself (an interval), not a
    // timer, so nothing is left pending when the widget goes away.
    final delay =
        FadeSlideIn.step * widget.index.clamp(0, FadeSlideIn.maxStagger);
    final total = delay + AppMotion.slow;
    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.enter,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _progress.value) * AppSpace.md),
        child: child,
      ),
    ),
  );
}

/// Something the user should notice appearing: a result, a code. Fades in
/// while growing from slightly smaller, once.
class Reveal extends StatelessWidget {
  const Reveal({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.94 + 0.06 * value, child: child),
      ),
    );
  }
}

/// A press response for custom tappable surfaces (cards): a slight
/// shrink while the finger is down. Buttons get the same from
/// [AppMotion]-timed colour changes in their own styles.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// A figure that counts up from zero when it first shows, then holds. The
/// final text is what assistive technology reads; it never animates for
/// it, and with reduced motion the final text shows at once.
class CountUpText extends StatelessWidget {
  const CountUpText({
    required this.value,
    required this.format,
    this.style,
    super.key,
  });

  final double value;

  /// Turns a number (part-way or final) into its text.
  final String Function(double value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final finalText = format(value);
    if (reduceMotion(context) || value == 0) {
      return Text(finalText, style: style);
    }
    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, shown, _) => Text(format(shown), style: style),
      ),
    );
  }
}

/// Page changes: the new page fades in while rising a little. With reduced
/// motion, a plain fade. Used for every platform except iOS, which keeps
/// its own swipe-back transition.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.slow;

  @override
  Duration get reverseTransitionDuration => AppMotion.base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    if (reduceMotion(context)) {
      return FadeTransition(opacity: curved, child: child);
    }
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
