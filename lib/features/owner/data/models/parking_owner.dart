import 'package:app/core/api/json_converters.dart';
import 'package:app/features/owner/data/models/verification_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_owner.freezed.dart';
part 'parking_owner.g.dart';

/// An owner application and its review.
@freezed
abstract class ParkingOwner with _$ParkingOwner {
  const factory ParkingOwner({
    required String id,
    required String businessName,
    required String contactPhone,
    @JsonKey(unknownEnumValue: VerificationStatus.unknown)
    required VerificationStatus verificationStatus,
    String? rejectionReason,
    @UtcDateTimeConverter() DateTime? verifiedAt,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _ParkingOwner;

  factory ParkingOwner.fromJson(Map<String, dynamic> json) =>
      _$ParkingOwnerFromJson(json);
}
