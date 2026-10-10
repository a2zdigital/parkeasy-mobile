import 'package:app/core/api/json_converters.dart';
import 'package:app/features/owner/data/models/approval_status.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner_parking_lot.freezed.dart';
part 'owner_parking_lot.g.dart';

/// A facility as its owner sees it: the public details plus its review state.
@freezed
abstract class OwnerParkingLot with _$OwnerParkingLot {
  const factory OwnerParkingLot({
    @JsonKey(readValue: _wholeObject) required ParkingLot lot,
    @JsonKey(unknownEnumValue: ApprovalStatus.unknown)
    required ApprovalStatus approvalStatus,
    String? rejectionReason,
    @Default(false) bool isActive,
    @UtcDateTimeConverter() DateTime? submittedAt,
    @UtcDateTimeConverter() DateTime? reviewedAt,
    @UtcDateTimeConverter() required DateTime createdAt,
    @UtcDateTimeConverter() required DateTime updatedAt,
  }) = _OwnerParkingLot;

  factory OwnerParkingLot.fromJson(Map<String, dynamic> json) =>
      _$OwnerParkingLotFromJson(json);
}

// The facility's fields sit beside the review fields in the same JSON
// object, so the nested model reads the whole object.
Object? _wholeObject(Map<dynamic, dynamic> json, String key) => json;
