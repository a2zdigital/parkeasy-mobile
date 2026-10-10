import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What a screen shows when there is nothing to show yet: what belongs
/// here, and the action that fills it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _Centered(
    icon: icon,
    iconColor: context.colors.textSecondary,
    title: title,
    body: body,
    footer: action,
  );
}

/// What a screen shows when it could not load: what happened, a way to
/// try again, and the request reference for support.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.failure,
    required this.onRetry,
    this.message,
    this.onNavy = false,
    super.key,
  });

  final ApiException failure;
  final VoidCallback onRetry;

  /// The screen's own words, when it knows better than the general text.
  final String? message;
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final requestId = failure.requestId;

    return _Centered(
      icon: Icons.cloud_off_outlined,
      iconColor: onNavy ? context.colors.onNavy : context.colors.danger.solid,
      title: l10n.errorTitle,
      body: message ?? l10n.describe(failure),
      caption: requestId == null ? null : l10n.errorReference(requestId),
      onNavy: onNavy,
      footer: SecondaryButton(label: l10n.actionTryAgain, onPressed: onRetry),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.caption,
    this.footer,
    this.onNavy = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String? caption;
  final Widget? footer;
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final caption = this.caption;
    final footer = this.footer;
    final strong = onNavy ? colors.onNavy : colors.textPrimary;
    final soft = onNavy ? colors.onNavy : colors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppSize.touchTarget, color: iconColor),
          ),
          const Gap.lg(),
          Text(
            title,
            style: text.h3.copyWith(color: strong),
            textAlign: TextAlign.center,
          ),
          const Gap.sm(),
          Text(
            body,
            style: text.body.copyWith(color: soft),
            textAlign: TextAlign.center,
          ),
          if (caption != null) ...[
            const Gap.sm(),
            SelectableText(
              caption,
              style: text.label.copyWith(color: soft),
              textAlign: TextAlign.center,
            ),
          ],
          if (footer != null) ...[const Gap.xl(), footer],
        ],
      ),
    );
  }
}
