import 'package:app/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// A card heading with its status chip at the end. The chip may take at
/// most half the width, so with large text both wrap instead of
/// overflowing.
class TitleWithStatus extends StatelessWidget {
  const TitleWithStatus({required this.title, required this.status, super.key});

  final Widget title;
  final Widget status;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const Gap.sm(),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
          child: status,
        ),
      ],
    ),
  );
}
