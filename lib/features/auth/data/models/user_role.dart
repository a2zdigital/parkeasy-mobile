import 'package:freezed_annotation/freezed_annotation.dart';

/// A role held by a user. One user can hold several.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum UserRole {
  customer('customer'),
  owner('owner'),
  operations('operations'),
  admin('admin'),
  unknown('unknown');

  const UserRole(this.wire);

  /// The value as the API writes it.
  final String wire;
}
