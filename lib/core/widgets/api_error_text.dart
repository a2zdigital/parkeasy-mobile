import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/l10n/l10n.dart';

/// The app's own words for the failures every screen can meet. A screen
/// handles the codes that mean something specific to it first, and falls
/// back to this for the rest. The API's English message is never shown.
extension ApiErrorText on AppLocalizations {
  String describe(ApiException failure) => switch (failure.code) {
    ApiErrorCode.network => errorNetwork,
    ApiErrorCode.timeout => errorTimeout,
    ApiErrorCode.serviceUnavailable ||
    ApiErrorCode.internalError => errorServer,
    ApiErrorCode.rateLimited || ApiErrorCode.otpAttemptsExceeded
        when failure.retryAfter != null =>
      errorRateLimited(failure.retryAfter!.inSeconds),
    ApiErrorCode.rateLimited => errorRateLimitedNoTime,
    ApiErrorCode.accountSuspended => errorSuspended,
    ApiErrorCode.appUpdateRequired ||
    ApiErrorCode.apiVersionRetired => errorUpdateRequired,
    _ => errorGeneric,
  };
}
