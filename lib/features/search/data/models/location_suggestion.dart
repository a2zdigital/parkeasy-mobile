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
    // The address split by the provider, when it gives the parts. Null
    // means unknown; the app then splits the formatted address itself.
    @JsonKey(name: 'address_line') String? addressLine,
    String? city,
    String? state,
    @JsonKey(name: 'postal_code') String? postalCode,
  }) = _LocationSuggestion;

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) =>
      _$LocationSuggestionFromJson(json);
}
