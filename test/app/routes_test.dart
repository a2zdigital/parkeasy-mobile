import 'package:app/app/routes.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:app/features/auth/state/registration_role.dart';
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
    Routes.registrationRole,
    Routes.registrationPhone,
    Routes.completeProfile,
    Routes.explore,
    Routes.bookings,
    Routes.activity,
    Routes.profile,
    Routes.owner,
    Routes.ownerBookings,
    Routes.ownerFacilities,
    Routes.ownerEarnings,
    Routes.ownerActivity,
    Routes.ownerProfile,
    Routes.ownerProfileEdit,
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
    for (final location in [
      Routes.launch,
      Routes.phone,
      Routes.code,
      Routes.registrationRole,
      Routes.registrationPhone,
    ]) {
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

  test(
    'owner registration resumes at the application after profile completion',
    () {
      final ownerRegistration = SignedIn(
        User.fromJson(userJson()),
        registrationRole: RegistrationRole.owner,
      );
      expect(Routes.redirect(ownerRegistration, Routes.explore), Routes.owner);
      expect(Routes.redirect(ownerRegistration, Routes.owner), isNull);
    },
  );

  test('incomplete owner registration resumes at profile completion', () {
    final ownerRegistration = SignedIn(
      User.fromJson(userJson(name: null, complete: false)),
      registrationRole: RegistrationRole.owner,
    );
    expect(
      Routes.redirect(ownerRegistration, Routes.explore),
      Routes.completeProfile,
    );
    expect(Routes.redirect(ownerRegistration, Routes.completeProfile), isNull);
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
      Routes.registrationRole,
      Routes.registrationPhone,
      Routes.completeProfile,
    ]) {
      expect(
        Routes.redirect(complete, location),
        Routes.explore,
        reason: location,
      );
    }
  });

  test('owner-only routes require the backend-granted owner role', () {
    final customer = SignedIn(User.fromJson(userJson()));
    final owner = SignedIn(
      User.fromJson(userJson(roles: const ['customer', 'owner'])),
    );

    expect(Routes.redirect(customer, Routes.owner), Routes.explore);
    expect(Routes.redirect(customer, Routes.ownerBookings), Routes.explore);
    expect(Routes.redirect(customer, Routes.ownerFacilities), Routes.explore);
    expect(Routes.redirect(customer, Routes.ownerEarnings), Routes.explore);
    expect(Routes.redirect(customer, Routes.ownerActivity), Routes.explore);
    expect(Routes.redirect(customer, Routes.ownerProfile), Routes.explore);
    expect(Routes.redirect(owner, Routes.ownerBookings), isNull);
    expect(Routes.redirect(owner, Routes.ownerFacilities), isNull);
    expect(Routes.redirect(owner, Routes.ownerEarnings), isNull);
    expect(Routes.redirect(owner, Routes.ownerActivity), isNull);
    expect(Routes.redirect(owner, Routes.ownerProfile), isNull);
    expect(Routes.redirect(owner, Routes.explore), Routes.ownerBookings);
    expect(Routes.redirect(owner, Routes.startUp), Routes.ownerBookings);
  });

  test('pending owner intent opens application but never owner modules', () {
    final pending = SignedIn(
      User.fromJson(userJson()),
      registrationRole: RegistrationRole.owner,
    );
    expect(Routes.redirect(pending, Routes.explore), Routes.owner);
    expect(Routes.redirect(pending, Routes.owner), isNull);
    expect(Routes.redirect(pending, Routes.ownerBookings), Routes.owner);
    expect(Routes.redirect(pending, Routes.ownerFacilities), Routes.owner);
  });

  test('unknown or missing role is treated as customer, never owner', () {
    for (final roles in [
      const <String>[],
      const ['future_role'],
    ]) {
      final session = SignedIn(User.fromJson(userJson(roles: roles)));
      expect(Routes.redirect(session, Routes.explore), isNull);
      expect(Routes.redirect(session, Routes.ownerBookings), Routes.explore);
    }
  });
}
