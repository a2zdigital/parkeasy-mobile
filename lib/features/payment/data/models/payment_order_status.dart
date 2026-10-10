import 'package:freezed_annotation/freezed_annotation.dart';

/// The state of an online payment. Only `succeeded` from the API means the money arrived.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum PaymentOrderStatus {
  created('created'),
  pending('pending'),
  succeeded('succeeded'),
  failed('failed'),
  partiallyRefunded('partially_refunded'),
  refunded('refunded'),
  unknown('unknown');

  const PaymentOrderStatus(this.wire);

  /// The value as the API writes it.
  final String wire;
}
