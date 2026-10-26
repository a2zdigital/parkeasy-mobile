import 'dart:async';

import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/data/models/session.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The single owner of "who is signed in". It writes and clears the
/// token; nothing else does.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // The API refused the token somewhere in the app: sign out everywhere.
    final subscription = ref
        .watch(authEventsProvider)
        .unauthenticated
        .listen((_) => unawaited(expire()));
    ref.onDispose(subscription.cancel);

    return const SessionUnknown();
  }

  /// Called once at start-up, and again from the "Try again" action.
  Future<void> restore() async {
    state = const SessionUnknown();

    final token = await ref.read(tokenStoreProvider).read();
    final now = ref.read(clockProvider)().toUtc();
    if (token == null || token.isExpiredAt(now)) {
      await expire();
      return;
    }

    try {
      state = SignedIn(await ref.read(authRepositoryProvider).currentUser());
    } on ApiException catch (failure) {
      if (failure.code == ApiErrorCode.unauthenticated) {
        await expire();
      } else {
        state = SessionRestoreFailed(failure);
      }
    }
  }

  /// After a sign-in code was verified.
  Future<void> start(Session session) async {
    await ref
        .read(tokenStoreProvider)
        .write(StoredToken(value: session.token, expiresAt: session.expiresAt));
    state = SignedIn(session.user);
  }

  /// After the profile changed.
  void updateUser(User user) {
    if (state is SignedIn) {
      state = SignedIn(user);
    }
  }

  /// The user chose to sign out. The server is told, but signing out on
  /// this device never waits for or depends on the answer.
  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // Offline or already invalid: the local sign-out still happens.
    }
    await expire();
  }

  /// The token is gone or no longer accepted.
  Future<void> expire() async {
    await ref.read(tokenStoreProvider).clear();
    state = const SignedOut();
  }
}
