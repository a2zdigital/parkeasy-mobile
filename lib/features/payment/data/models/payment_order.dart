import 'package:app/core/api/json_converters.dart';
import 'package:app/core/money/money.dart';
import 'package:app/features/payment/data/models/payment_order_status.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_order.freezed.dart';
part 'payment_order.g.dart';

/// An attempt to pay for a booking online. `checkout` holds what the payment screen needs and is null once the order can no longer be paid.
@freezed
abstract class PaymentOrder with _$PaymentOrder {
  const PaymentOrder._();

  const factory PaymentOrder({
    required String id,
    required String bookingId,
    @JsonKey(unknownEnumValue: PaymentOrderStatus.unknown)
    required PaymentOrderStatus status,
    @MoneyAmountConverter() required Decimal amount,
    required String currency,
    required String provider,
    Map<String, dynamic>? checkout,
    @UtcDateTimeConverter() DateTime? expiresAt,
    @UtcDateTimeConverter() DateTime? paidAt,
  }) = _PaymentOrder;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) =>
      _$PaymentOrderFromJson(json);

  Money get total => Money(amount, currency);
}
