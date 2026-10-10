import 'package:app/features/booking/data/models/quote.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';

/// What the customer chose and the price the API gave for it, carried
/// from the choose-time screen to the review screen.
class BookingDraft {
  const BookingDraft({
    required this.lot,
    required this.vehicleType,
    required this.startAt,
    required this.endAt,
    required this.quote,
  });

  final ParkingLot lot;

  /// Vehicle-type code.
  final String vehicleType;
  final DateTime startAt;
  final DateTime endAt;
  final Quote quote;

  /// The display name of the vehicle type, from the facility's pools.
  String get vehicleTypeName {
    for (final pool in lot.pools) {
      if (pool.vehicleType.code == vehicleType) return pool.vehicleType.name;
    }
    return vehicleType;
  }
}
