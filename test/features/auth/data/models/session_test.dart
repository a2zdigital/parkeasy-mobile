import 'package:app/features/auth/data/models/otp_challenge.dart';
import 'package:app/features/auth/data/models/session.dart';
import 'package:app/features/auth/data/models/user_role.dart';
import 'package:app/features/auth/data/models/user_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> sessionJson() => {
    'token': '12|abcdef',
    'token_type': 'Bearer',
    'expires_at': '2027-01-08T10:00:00Z',
    'is_new_user': true,
    'user': {
      'id': '01M4JQSZSNAVTVCMS8A7AJ0USR',
      'name': null,
      'phone': '+919000000001',
      'email': null,
      'status': 'active',
      'roles': ['customer', 'owner'],
      'is_profile_complete': false,
      'created_at': '2026-10-10T10:00:00Z',
    },
  };

  test('Session parses a new user with no name yet', () {
    final session = Session.fromJson(sessionJson());

    expect(session.token, '12|abcdef');
    expect(session.isNewUser, isTrue);
    expect(session.expiresAt, DateTime.utc(2027, 1, 8, 10));
    expect(session.user.name, isNull);
    expect(session.user.status, UserStatus.active);
    expect(session.user.roles, [UserRole.customer, UserRole.owner]);
    expect(session.user.isOwner, isTrue);
    expect(session.user.isProfileComplete, isFalse);
  });

  test('User survives a role and status added later', () {
    final json = sessionJson();
    (json['user'] as Map<String, dynamic>)
      ..['roles'] = ['customer', 'attendant']
      ..['status'] = 'under_review';

    final user = Session.fromJson(json).user;

    expect(user.roles, [UserRole.customer, UserRole.unknown]);
    expect(user.status, UserStatus.unknown);
    expect(user.isOwner, isFalse);
  });

  test('OtpChallenge parses', () {
    final challenge = OtpChallenge.fromJson({
      'expires_in': 300,
      'resend_in': 30,
    });

    expect(challenge.expiresIn, 300);
    expect(challenge.resendIn, 30);
  });
}
