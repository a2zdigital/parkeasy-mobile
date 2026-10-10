import 'package:freezed_annotation/freezed_annotation.dart';

part 'operating_hour.freezed.dart';
part 'operating_hour.g.dart';

/// Opening hours for one day of the week (1 is Monday, 7 is Sunday), in the facility's timezone. Times are `HH:mm`; `24:00` means the end of the day.
@freezed
abstract class OperatingHour with _$OperatingHour {
  const factory OperatingHour({
    required int dayOfWeek,
    @Default(false) bool isClosed,
    String? opensAt,
    String? closesAt,
  }) = _OperatingHour;

  factory OperatingHour.fromJson(Map<String, dynamic> json) =>
      _$OperatingHourFromJson(json);
}
