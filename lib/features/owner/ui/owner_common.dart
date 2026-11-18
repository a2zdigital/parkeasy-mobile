import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/l10n/l10n.dart';

/// The words for "this account may not use the owner area yet". The API
/// decides who may; the app only explains the refusal.
String? ownerAccessText(AppLocalizations l10n, ApiException failure) =>
    switch (failure.code) {
      ApiErrorCode.ownerNotVerified ||
      ApiErrorCode.ownerProfileNotFound ||
      ApiErrorCode.forbidden => l10n.ownerNotVerified,
      _ => null,
    };
