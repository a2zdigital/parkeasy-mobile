import 'package:freezed_annotation/freezed_annotation.dart';

part 'operating_hour_input.freezed.dart';
part 'operating_hour_input.g.dart';

/// Opening hours for one day, as sent when an owner sets them.
@freezed
abstract class OperatingHourInput with _$OperatingHourInput {
  const factory OperatingHourInput({
    required int dayOfWeek,
    @Default(false) bool isClosed,
    String? opensAt,
    String? closesAt,
  }) = _OperatingHourInput;

  factory OperatingHourInput.fromJson(Map<String, dynamic> json) =>
      _$OperatingHourInputFromJson(json);
}
