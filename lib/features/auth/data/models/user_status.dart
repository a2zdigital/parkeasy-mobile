import 'package:freezed_annotation/freezed_annotation.dart';

/// Whether the account may use the API.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum UserStatus {
  active('active'),
  suspended('suspended'),
  unknown('unknown');

  const UserStatus(this.wire);

  /// The value as the API writes it.
  final String wire;
}
