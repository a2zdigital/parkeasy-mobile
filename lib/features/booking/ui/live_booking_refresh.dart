import 'dart:async';

import 'package:flutter/widgets.dart';

/// Re-reads a booking every few seconds while [active], so a check-in or
/// check-out done at the gate shows on the customer's phone without them
/// pulling to refresh. Draws nothing.
class LiveBookingRefresh extends StatefulWidget {
  const LiveBookingRefresh({
    required this.active,
    required this.onTick,
    this.every = defaultEvery,
    super.key,
  });

  final bool active;
  final Future<void> Function() onTick;
  final Duration every;

  static const Duration defaultEvery = Duration(seconds: 5);

  @override
  State<LiveBookingRefresh> createState() => _LiveBookingRefreshState();
}

class _LiveBookingRefreshState extends State<LiveBookingRefresh> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveBookingRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.every != widget.every) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    _timer = widget.active
        ? Timer.periodic(widget.every, (_) => _tick())
        : null;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await widget.onTick();
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
