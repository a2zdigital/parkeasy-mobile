import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// A money amount: the API's decimal string, never a double.
class MoneyAmountConverter implements JsonConverter<Decimal, String> {
  const MoneyAmountConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toStringAsFixed(2);
}

/// A decimal that is not money, such as a commission rate (`"15"`).
class DecimalConverter implements JsonConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toString();
}

/// A timestamp. Always UTC in memory; sent as ISO 8601 with `Z` and no
/// fraction, which is the form the API documents.
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();

  @override
  String toJson(DateTime object) {
    final utc = object.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}'
        'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }
}

/// A coordinate or distance. Accepts a JSON number or a numeric string,
/// because decimal database columns are sometimes serialised as strings.
class FlexibleDoubleConverter implements JsonConverter<double, Object> {
  const FlexibleDoubleConverter();

  @override
  double fromJson(Object json) => switch (json) {
    final num value => value.toDouble(),
    final String value => double.parse(value),
    _ => throw FormatException('Not a number', json),
  };

  @override
  Object toJson(double object) => object;
}

/// A free-form JSON object. An empty PHP array arrives as `[]`, so a list
/// (or anything that is not an object) is read as an empty map.
class JsonObjectConverter
    implements JsonConverter<Map<String, dynamic>, Object?> {
  const JsonObjectConverter();

  @override
  Map<String, dynamic> fromJson(Object? json) =>
      json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

  @override
  Object? toJson(Map<String, dynamic> object) => object;
}
