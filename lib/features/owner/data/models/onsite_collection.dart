import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onsite_collection.freezed.dart';
part 'onsite_collection.g.dart';

/// A record that the customer paid at the facility.
@freezed
abstract class OnsiteCollection with _$OnsiteCollection {
  const OnsiteCollection._();

  const factory OnsiteCollection({
    required String id,
    required String bookingId,
    @MoneyAmountConverter() required Decimal amount,
    required String currency,
    @UtcDateTimeConverter() required DateTime collectedAt,
  }) = _OnsiteCollection;

  factory OnsiteCollection.fromJson(Map<String, dynamic> json) =>
      _$OnsiteCollectionFromJson(json);

  Money get total => Money(amount, currency);
}
