import 'package:app/core/api/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner_document.freezed.dart';
part 'owner_document.g.dart';

/// What an owner's document proves. [unknown] stands for a value added to
/// the API after this app was built.
@JsonEnum(valueField: 'wire')
enum OwnerDocumentType {
  identity('identity'),
  business('business'),
  property('property'),
  licence('licence'),
  unknown('unknown');

  const OwnerDocumentType(this.wire);

  final String wire;
}

/// A document sent with the owner application. [url] is signed and stops
/// working after a few minutes; reading the list again gives fresh ones.
@freezed
abstract class OwnerDocument with _$OwnerDocument {
  const factory OwnerDocument({
    required String id,
    @JsonKey(unknownEnumValue: OwnerDocumentType.unknown)
    required OwnerDocumentType type,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    required String url,
    @UtcDateTimeConverter() required DateTime createdAt,

    /// The expiry date the owner or staff entered, as YYYY-MM-DD. The
    /// owner is reminded before it and staff review it after.
    String? expiresOn,
    @JsonKey(readValue: _parkingLotName) String? parkingLotName,
    @Default(false) bool isExpired,
  }) = _OwnerDocument;

  factory OwnerDocument.fromJson(Map<String, dynamic> json) =>
      _$OwnerDocumentFromJson(json);
}

Object? _parkingLotName(Map<dynamic, dynamic> json, String key) {
  final parkingLot = json['parking_lot'];
  return parkingLot is Map ? parkingLot['name'] : null;
}
