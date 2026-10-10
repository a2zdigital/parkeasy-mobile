import 'package:freezed_annotation/freezed_annotation.dart';

/// What a commission entry records.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum EarningKind {
  earned('earned'),
  reversed('reversed'),
  owedOnsite('owed_onsite'),
  unknown('unknown');

  const EarningKind(this.wire);

  /// The value as the API writes it.
  final String wire;
}
