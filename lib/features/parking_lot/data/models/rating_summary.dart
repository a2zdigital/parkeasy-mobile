import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_summary.freezed.dart';
part 'rating_summary.g.dart';

/// A facility's score from its visible ratings. [average] is a decimal
/// string such as "4.3", null while there are no ratings.
@freezed
abstract class RatingSummary with _$RatingSummary {
  const factory RatingSummary({String? average, @Default(0) int count}) =
      _RatingSummary;

  factory RatingSummary.fromJson(Map<String, dynamic> json) =>
      _$RatingSummaryFromJson(json);
}
