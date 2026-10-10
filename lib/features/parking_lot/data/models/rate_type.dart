import 'package:freezed_annotation/freezed_annotation.dart';

/// The unit a rate is charged in.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum RateType {
  hourly('hourly'),
  daily('daily'),
  unknown('unknown');

  const RateType(this.wire);

  /// The value as the API writes it.
  final String wire;
}
