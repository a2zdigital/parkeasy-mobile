import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:flutter/material.dart';

/// Asks before a destructive or costly action. The title is the question,
/// the body states the consequence, the confirm label names the action.
///
/// Returns true only when the user confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: context.colors.surface,
      surfaceTintColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.text.h3),
            const Gap.sm(),
            Text(
              body,
              style: context.text.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const Gap.xl(),
            PrimaryButton(
              label: confirmLabel,
              isDestructive: isDestructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const Gap.sm(),
            TextAction(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
