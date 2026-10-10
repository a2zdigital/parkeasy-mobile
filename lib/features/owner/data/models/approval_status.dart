import 'package:freezed_annotation/freezed_annotation.dart';

/// The review state of a facility.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum ApprovalStatus {
  draft('draft'),
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  unknown('unknown');

  const ApprovalStatus(this.wire);

  /// The value as the API writes it.
  final String wire;
}
