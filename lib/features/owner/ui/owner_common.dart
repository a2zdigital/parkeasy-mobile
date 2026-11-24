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

/// Why the API refused a check-in.
///
/// `CHECK_IN_NOT_ALLOWED` carries no structured reason, only the API's
/// message, which names it ("too early", "already ended", "already been
/// checked in"). Those three messages are matched; anything else shows the
/// API's own message, or a neutral text when there is none.
String checkInRefusalText(AppLocalizations l10n, ApiException failure) {
  final message = failure.message;
  final lower = message?.toLowerCase() ?? '';
  if (lower.contains('too early')) return l10n.errCheckInTooEarly;
  if (lower.contains('already ended')) return l10n.errCheckInEnded;
  if (lower.contains('already been checked in')) {
    return l10n.errCheckInAlreadyDone;
  }
  return message ?? l10n.errCheckInNotAllowed;
}
