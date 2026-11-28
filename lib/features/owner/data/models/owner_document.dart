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

/// The server's malware scan of a document. Only [clean] documents can be
/// opened. [unknown] stands for a value added to the API after this app was
/// built.
@JsonEnum(valueField: 'wire')
enum DocumentScanStatus {
  pending('pending'),
  clean('clean'),
  infected('infected'),
  failed('failed'),
  unknown('unknown');

  const DocumentScanStatus(this.wire);

  final String wire;
}

/// A document sent with the owner application. [url] is signed and stops
/// working after a few minutes; reading the list again gives fresh ones. It
/// is null until the malware scan has passed.
@freezed
abstract class OwnerDocument with _$OwnerDocument {
  const factory OwnerDocument({
    required String id,
    @JsonKey(unknownEnumValue: OwnerDocumentType.unknown)
    required OwnerDocumentType type,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    String? url,
    @JsonKey(unknownEnumValue: DocumentScanStatus.unknown)
    @Default(DocumentScanStatus.clean)
    DocumentScanStatus scanStatus,
    @UtcDateTimeConverter() required DateTime createdAt,

    /// The expiry date the owner or staff entered, as YYYY-MM-DD. The
    /// owner is reminded before it and staff review it after.
    String? expiresOn,
    @JsonKey(readValue: _parkingLotName) String? parkingLotName,

    /// The number on the card. An Aadhaar number comes back masked
    /// ("XXXX XXXX 1234"); a PAN in capitals.
    String? documentNumber,
    @Default(false) bool isExpired,

    /// Aadhaar and PAN only: what the identity service said about the card
    /// (verified, not_verified or unavailable); null before it answered.
    @JsonKey(readValue: _identityStatus) String? identityStatus,

    /// An Aadhaar card the owner can still confirm with the OTP sent to the
    /// mobile linked to their Aadhaar.
    @JsonKey(readValue: _awaitsAadhaarOtp)
    @Default(false)
    bool awaitsAadhaarOtp,
  }) = _OwnerDocument;

  factory OwnerDocument.fromJson(Map<String, dynamic> json) =>
      _$OwnerDocumentFromJson(json);
}

Object? _identityStatus(Map<dynamic, dynamic> json, String key) {
  final identity = json['identity_verification'];
  return identity is Map ? identity['status'] : null;
}

Object? _awaitsAadhaarOtp(Map<dynamic, dynamic> json, String key) {
  final identity = json['identity_verification'];
  return identity is Map ? identity['awaits_aadhaar_otp'] : null;
}

Object? _parkingLotName(Map<dynamic, dynamic> json, String key) {
  final parkingLot = json['parking_lot'];
  return parkingLot is Map ? parkingLot['name'] : null;
}
