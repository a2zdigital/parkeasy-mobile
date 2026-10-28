import 'package:app/core/api/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_suggestion.freezed.dart';
part 'location_suggestion.g.dart';

@freezed
abstract class LocationSuggestion with _$LocationSuggestion {
  const factory LocationSuggestion({
    required String id,
    required String name,
    required String address,
    @FlexibleDoubleConverter() required double latitude,
    @FlexibleDoubleConverter() required double longitude,
  }) = _LocationSuggestion;

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) =>
      _$LocationSuggestionFromJson(json);
}
