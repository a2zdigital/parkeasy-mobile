import 'dart:async';

import 'package:app/core/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rebuilds once a second with the whole seconds left until [deadline],
/// and stops at zero. Used for the resend wait and, later, payment and
/// approval deadlines. The deadline comes from the server; this only
/// counts down to it.
class CountdownBuilder extends ConsumerStatefulWidget {
  const CountdownBuilder({
    required this.deadline,
    required this.builder,
    super.key,
  });

  final DateTime deadline;
  final Widget Function(BuildContext context, int secondsLeft) builder;

  @override
  ConsumerState<CountdownBuilder> createState() => _CountdownBuilderState();
}

class _CountdownBuilderState extends ConsumerState<CountdownBuilder> {
  Timer? _timer;

  int get _secondsLeft {
    final left = widget.deadline.difference(ref.read(clockProvider)());
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(CountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (_secondsLeft == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) timer.cancel();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _secondsLeft);
}
