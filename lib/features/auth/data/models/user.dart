import 'package:app/core/api/json_converters.dart';
import 'package:app/features/auth/data/models/user_role.dart';
import 'package:app/features/auth/data/models/user_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// The signed-in person.
@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    required String id,
    String? name,
    required String phone,
    String? email,
    @JsonKey(unknownEnumValue: UserStatus.unknown) required UserStatus status,
    @JsonKey(unknownEnumValue: UserRole.unknown)
    @Default(<UserRole>[])
    List<UserRole> roles,
    @Default(false) bool isProfileComplete,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  bool get isOwner => roles.contains(UserRole.owner);
}
