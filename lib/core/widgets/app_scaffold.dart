import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The frame of every screen: canvas colour, safe areas, the standard
/// horizontal padding, scrolling content, and an action area that stays
/// above the keyboard. No screen sets its own padding.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.title,
    this.actions,
    this.bottom,
    this.onNavy = false,
    this.scrollable = true,
    super.key,
  });

  /// Shown in the top bar. Without it there is no top bar.
  final String? title;
  final List<Widget>? actions;
  final Widget body;

  /// Pinned under the content: the screen's main action.
  final Widget? bottom;

  /// The navy brand surface: launch and start-up only.
  final bool onNavy;

  /// False for screens whose body manages its own scrolling (lists).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    final bottom = this.bottom;
    final padding = MediaQuery.sizeOf(context).width < AppSize.compactWidth
        ? AppSize.screenPaddingCompact
        : AppSize.screenPadding;

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: body,
    );
    if (scrollable) {
      // Fills the height when the content is short (so a centred body is
      // centred) and scrolls when it is long or the text is large.
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: body,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: onNavy ? colors.brandNavy : colors.canvas,
      appBar: title == null
          ? null
          : AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: content),
            if (bottom != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppSpace.md,
                  padding,
                  AppSpace.lg,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}
