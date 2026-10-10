import 'package:freezed_annotation/freezed_annotation.dart';

/// Where a booking is in its life. Only the API changes it.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum BookingStatus {
  pendingApproval('pending_approval'),
  awaitingPayment('awaiting_payment'),
  confirmed('confirmed'),
  rejected('rejected'),
  cancelled('cancelled'),
  completed('completed'),
  expired('expired'),
  noShow('no_show'),
  unknown('unknown');

  const BookingStatus(this.wire);

  /// The value as the API writes it.
  final String wire;
}
