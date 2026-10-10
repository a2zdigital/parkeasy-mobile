import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/booking/data/models/price_line.dart';
import 'package:app/features/parking_lot/data/models/booking_mode.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'quote.freezed.dart';
part 'quote.g.dart';

/// The price the API calculated for a window, and the terms a booking would carry.
@freezed
abstract class Quote with _$Quote {
  const Quote._();

  const factory Quote({
    required String parkingLotId,
    required String vehicleType,
    @UtcDateTimeConverter() required DateTime startAt,
    @UtcDateTimeConverter() required DateTime endAt,
    required String timezone,
    @JsonKey(unknownEnumValue: BookingMode.unknown)
    required BookingMode bookingMode,
    @Default(false) bool acceptsOnlinePayment,
    @Default(false) bool acceptsOnsitePayment,
    @Default(<PriceLine>[]) List<PriceLine> lines,
    @MoneyAmountConverter() required Decimal baseAmount,
    @MoneyAmountConverter() required Decimal totalAmount,
    required String currency,
  }) = _Quote;

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);

  Money get total => Money(totalAmount, currency);
}
