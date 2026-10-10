import 'package:freezed_annotation/freezed_annotation.dart';

/// How spaces in a pool are handed out.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum AllocationMode {
  pooled('pooled'),
  numbered('numbered'),
  unknown('unknown');

  const AllocationMode(this.wire);

  /// The value as the API writes it.
  final String wire;
}
