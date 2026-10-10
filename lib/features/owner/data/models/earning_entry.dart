import 'package:app/core/api/json_converters.dart';
import 'package:app/features/owner/data/models/earning_kind.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'earning_entry.freezed.dart';
part 'earning_entry.g.dart';

/// One booking's commission entry.
@freezed
abstract class EarningEntry with _$EarningEntry {
  const factory EarningEntry({
    required String id,
    required String bookingId,
    @JsonKey(unknownEnumValue: EarningKind.unknown) required EarningKind kind,
    @MoneyAmountConverter() required Decimal baseAmount,
    @DecimalConverter() required Decimal commissionRate,
    @MoneyAmountConverter() required Decimal commissionAmount,
    @MoneyAmountConverter() required Decimal ownerAmount,
    required String currency,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _EarningEntry;

  factory EarningEntry.fromJson(Map<String, dynamic> json) =>
      _$EarningEntryFromJson(json);
}
