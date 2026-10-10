import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/booking/data/models/payment_mode.dart';
import 'package:app/features/owner/data/models/onsite_collection.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onsite_collection_state.freezed.dart';
part 'onsite_collection_state.g.dart';

/// What is due at the facility for a booking, and the collection once it is recorded.
@freezed
abstract class OnsiteCollectionState with _$OnsiteCollectionState {
  const OnsiteCollectionState._();

  const factory OnsiteCollectionState({
    @JsonKey(unknownEnumValue: PaymentMode.unknown)
    required PaymentMode paymentMode,
    @MoneyAmountConverter() required Decimal amountDue,
    required String currency,
    OnsiteCollection? collection,
  }) = _OnsiteCollectionState;

  factory OnsiteCollectionState.fromJson(Map<String, dynamic> json) =>
      _$OnsiteCollectionStateFromJson(json);

  Money get due => Money(amountDue, currency);
}
