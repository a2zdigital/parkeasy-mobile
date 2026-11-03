import 'dart:async';

import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/auth/token_store.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/data/models/session.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:app/features/auth/state/registration_role.dart';
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
      final user = await ref.read(authRepositoryProvider).currentUser();
      final storedIntent = await ref
          .read(tokenStoreProvider)
          .readRegistrationIntent();
      var registrationRole = RegistrationRole.fromStorageValue(storedIntent);
      if (user.isOwner ||
          registrationRole == null ||
          (registrationRole == RegistrationRole.customer &&
              user.isProfileComplete)) {
        await ref.read(tokenStoreProvider).clearRegistrationIntent();
        registrationRole = null;
      }
      state = SignedIn(user, registrationRole: registrationRole);
    } on ApiException catch (failure) {
      if (failure.code == ApiErrorCode.unauthenticated) {
        await expire();
      } else {
        state = SessionRestoreFailed(failure);
      }
    }
  }

  /// After a sign-in code was verified.
  Future<void> start(
    Session session, {
    RegistrationRole? registrationRole,
  }) async {
    final tokenStore = ref.read(tokenStoreProvider);
    await tokenStore.write(
      StoredToken(value: session.token, expiresAt: session.expiresAt),
    );
    final pendingRole = session.isNewUser
        ? registrationRole ?? RegistrationRole.customer
        : null;
    if (pendingRole == null) {
      await tokenStore.clearRegistrationIntent();
    } else {
      await tokenStore.writeRegistrationIntent(pendingRole.storageValue);
    }
    state = SignedIn(session.user, registrationRole: pendingRole);
  }

  /// After the profile changed.
  void updateUser(User user) {
    final current = state;
    if (current is SignedIn) {
      state = SignedIn(user, registrationRole: current.registrationRole);
    }
  }

  /// Clears the saved onboarding intent only after the backend step succeeds.
  Future<void> finishRegistration({User? user}) async {
    final tokenStore = ref.read(tokenStoreProvider);
    await tokenStore.clearRegistrationIntent();
    final current = state;
    if (current is SignedIn) {
      state = SignedIn(user ?? current.user);
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
