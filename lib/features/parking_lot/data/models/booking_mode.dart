import 'package:freezed_annotation/freezed_annotation.dart';

/// Whether a booking is confirmed at once or needs the owner to accept it.
///
/// [unknown] stands for a value the API added after this app was built.
@JsonEnum(valueField: 'wire')
enum BookingMode {
  instant('instant'),
  ownerApproval('owner_approval'),
  unknown('unknown');

  const BookingMode(this.wire);

  /// The value as the API writes it.
  final String wire;
}
