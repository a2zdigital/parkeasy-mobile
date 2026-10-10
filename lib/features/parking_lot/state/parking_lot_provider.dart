import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:app/features/parking_lot/data/parking_lot_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One facility, by its public ID. Retry by invalidating it.
final parkingLotProvider = FutureProvider.autoDispose
    .family<ParkingLot, String>(
      (ref, id) => ref.watch(parkingLotRepositoryProvider).find(id),
    );
