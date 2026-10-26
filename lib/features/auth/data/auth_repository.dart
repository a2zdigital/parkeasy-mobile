import 'package:app/core/api/api_client.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/models/otp_challenge.dart';
import 'package:app/features/auth/data/models/session.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

/// Sign-in, sign-out and "who am I".
class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  /// Asks the API to send a sign-in code to [phone] (E.164).
  Future<OtpChallenge> requestOtp(String phone) async {
    final envelope = await _api.post(
      '/auth/otp/request',
      body: {'phone': phone},
    );
    return OtpChallenge.fromJson(ApiClient.object(envelope));
  }

  Future<Session> verifyOtp({
    required String phone,
    required String code,
    required String deviceName,
  }) async {
    final envelope = await _api.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code, 'device_name': deviceName},
    );
    return Session.fromJson(ApiClient.object(envelope));
  }

  Future<User> currentUser() async =>
      User.fromJson(ApiClient.object(await _api.get('/me')));

  /// Ends this device's session on the server.
  Future<void> logout() => _api.post('/auth/logout');
}
