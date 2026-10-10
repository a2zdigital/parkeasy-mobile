import 'package:freezed_annotation/freezed_annotation.dart';

part 'otp_challenge.freezed.dart';
part 'otp_challenge.g.dart';

/// What the API says after sending a sign-in code: how long it lasts and when another may be requested. Both in seconds.
@freezed
abstract class OtpChallenge with _$OtpChallenge {
  const factory OtpChallenge({required int expiresIn, required int resendIn}) =
      _OtpChallenge;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) =>
      _$OtpChallengeFromJson(json);
}
