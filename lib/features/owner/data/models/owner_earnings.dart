import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/owner/data/models/online_earnings.dart';
import 'package:app/features/owner/data/models/onsite_earnings.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner_earnings.freezed.dart';
part 'owner_earnings.g.dart';

/// An owner's money position: what the platform owes them and what they owe the platform.
@freezed
abstract class OwnerEarnings with _$OwnerEarnings {
  const OwnerEarnings._();

  const factory OwnerEarnings({
    required String currency,
    @MoneyAmountConverter() required Decimal payableBalance,
    @MoneyAmountConverter() required Decimal commissionOwed,
    required OnlineEarnings online,
    @JsonKey(name: 'on_site') required OnsiteEarnings onSite,
  }) = _OwnerEarnings;

  factory OwnerEarnings.fromJson(Map<String, dynamic> json) =>
      _$OwnerEarningsFromJson(json);

  Money get payable => Money(payableBalance, currency);

  Money get owed => Money(commissionOwed, currency);
}
