import 'package:app/core/api/json_converters.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// The result of verifying a sign-in code. The token goes to secure storage and nowhere else.
@freezed
abstract class Session with _$Session {
  const factory Session({
    required String token,
    @UtcDateTimeConverter() required DateTime expiresAt,
    @Default(false) bool isNewUser,
    required User user,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}
