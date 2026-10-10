import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The words for "this account may not use the owner area yet". The API
/// decides who may; the app only explains the refusal.
String? ownerAccessText(AppLocalizations l10n, ApiException failure) =>
    switch (failure.code) {
      ApiErrorCode.ownerNotVerified ||
      ApiErrorCode.ownerProfileNotFound ||
      ApiErrorCode.forbidden => l10n.ownerNotVerified,
      _ => null,
    };

/// Leaves the owner area for the customer's.
class ExitOwnerAreaAction extends StatelessWidget {
  const ExitOwnerAreaAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.ownerExit,
    icon: const Icon(Icons.swap_horiz_outlined),
    onPressed: () => context.go(Routes.profile),
  );
}
