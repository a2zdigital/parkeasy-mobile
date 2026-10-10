import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/data/models/user.dart';

/// Whether somebody is signed in. The router shows a different part of
/// the app for each case.
sealed class SessionState {
  const SessionState();
}

/// Start-up: the stored token has not been checked yet.
class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// A token is stored but the API could not be reached to confirm it. The
/// user stays signed in and can try again; they are not sent to sign-in
/// because they are offline.
class SessionRestoreFailed extends SessionState {
  const SessionRestoreFailed(this.failure);

  final ApiException failure;
}

class SignedOut extends SessionState {
  const SignedOut();
}

class SignedIn extends SessionState {
  const SignedIn(this.user);

  final User user;
}
