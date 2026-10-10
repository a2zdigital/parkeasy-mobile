import 'package:freezed_annotation/freezed_annotation.dart';

/// The state of an owner application.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum VerificationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  unknown('unknown');

  const VerificationStatus(this.wire);

  /// The value as the API writes it.
  final String wire;
}
