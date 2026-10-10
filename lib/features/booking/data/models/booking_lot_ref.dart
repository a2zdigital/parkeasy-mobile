import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_lot_ref.freezed.dart';
part 'booking_lot_ref.g.dart';

/// The facility a booking is for, as recorded when it was made.
@freezed
abstract class BookingLotRef with _$BookingLotRef {
  const factory BookingLotRef({required String id, required String name}) =
      _BookingLotRef;

  factory BookingLotRef.fromJson(Map<String, dynamic> json) =>
      _$BookingLotRefFromJson(json);
}
