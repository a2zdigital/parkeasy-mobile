import 'package:app/core/api/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner_payout.freezed.dart';
part 'owner_payout.g.dart';

/// Where a payout request stands.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum PayoutStatus {
  pendingReview('pending_review'),
  approved('approved'),
  processing('processing'),
  paid('paid'),
  failed('failed'),
  rejected('rejected'),
  cancelled('cancelled'),
  unknown('unknown');

  const PayoutStatus(this.wire);

  /// The value as the API writes it.
  final String wire;
}

/// A payout to the owner, as the platform recorded it. Read-only.
@freezed
abstract class OwnerPayout with _$OwnerPayout {
  const factory OwnerPayout({
    required String id,
    required String reference,
    @MoneyAmountConverter() required Decimal amount,
    required String currency,
    required String method,
    String? upiIdMasked,
    @JsonKey(unknownEnumValue: PayoutStatus.unknown)
    required PayoutStatus status,
    @UtcDateTimeConverter() DateTime? paidAt,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _OwnerPayout;

  factory OwnerPayout.fromJson(Map<String, dynamic> json) =>
      _$OwnerPayoutFromJson(json);
}
