import 'dart:async';

/// Tells the rest of the app that the API no longer accepts the token.
///
/// The API client raises it; the session listens and signs the user out.
/// It exists so the client does not depend on the session, and the
/// session does not depend on the client's construction.
class AuthEvents {
  final StreamController<void> _unauthenticated =
      StreamController<void>.broadcast();

  Stream<void> get unauthenticated => _unauthenticated.stream;

  void reportUnauthenticated() {
    if (!_unauthenticated.isClosed) {
      _unauthenticated.add(null);
    }
  }

  Future<void> dispose() => _unauthenticated.close();
}
