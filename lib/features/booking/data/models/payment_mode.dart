import 'package:freezed_annotation/freezed_annotation.dart';

/// How the customer pays for a booking.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum PaymentMode {
  online('online'),
  onSite('on_site'),
  unknown('unknown');

  const PaymentMode(this.wire);

  /// The value as the API writes it.
  final String wire;
}
