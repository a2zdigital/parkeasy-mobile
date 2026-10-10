import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  final complete = SignedIn(User.fromJson(userJson()));
  final incomplete = SignedIn(
    User.fromJson(userJson(name: null, complete: false)),
  );
  const signedOut = SignedOut();

  const everywhere = [
    Routes.startUp,
    Routes.launch,
    Routes.phone,
    Routes.code,
    Routes.completeProfile,
    Routes.explore,
    Routes.bookings,
    Routes.activity,
    Routes.profile,
  ];

  test('until the session is known, everything waits on start-up', () {
    const failed = SessionRestoreFailed(
      ApiException(code: ApiErrorCode.network),
    );
    for (final session in [const SessionUnknown(), failed]) {
      for (final location in everywhere) {
        expect(
          Routes.redirect(session, location),
          location == Routes.startUp ? isNull : Routes.startUp,
          reason: '$session at $location',
        );
      }
    }
  });

  test('signed out: only the sign-in screens are reachable', () {
    for (final location in [Routes.launch, Routes.phone, Routes.code]) {
      expect(Routes.redirect(signedOut, location), isNull, reason: location);
    }
    for (final location in [
      Routes.startUp,
      Routes.completeProfile,
      Routes.explore,
      Routes.bookings,
      Routes.activity,
      Routes.profile,
    ]) {
      expect(
        Routes.redirect(signedOut, location),
        Routes.launch,
        reason: location,
      );
    }
  });

  test('a new user must finish their profile before anything else', () {
    for (final location in everywhere) {
      expect(
        Routes.redirect(incomplete, location),
        location == Routes.completeProfile ? isNull : Routes.completeProfile,
        reason: location,
      );
    }
  });

  test('signed in: the app is open and the sign-in screens are not', () {
    for (final location in [
      Routes.explore,
      Routes.bookings,
      Routes.activity,
      Routes.profile,
    ]) {
      expect(Routes.redirect(complete, location), isNull, reason: location);
    }
    for (final location in [
      Routes.startUp,
      Routes.launch,
      Routes.phone,
      Routes.code,
      Routes.completeProfile,
    ]) {
      expect(
        Routes.redirect(complete, location),
        Routes.explore,
        reason: location,
      );
    }
  });
}
