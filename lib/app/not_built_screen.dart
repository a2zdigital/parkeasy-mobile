import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Stands in for a destination whose feature is not built. It says so
/// plainly; it does not imitate the real screen. Each use is removed when
/// its feature lands.
class NotBuiltScreen extends StatelessWidget {
  const NotBuiltScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: title,
    body: Center(
      child: EmptyState(
        icon: Icons.construction_outlined,
        title: context.l10n.notBuiltTitle,
        body: context.l10n.notBuiltBody,
      ),
    ),
  );
}
