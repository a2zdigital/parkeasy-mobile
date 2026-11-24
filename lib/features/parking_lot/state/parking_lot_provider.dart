import 'package:app/features/parking_lot/data/models/facility_review.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:app/features/parking_lot/data/parking_lot_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A facility's newest reviews. Retry by invalidating it.
final facilityReviewsProvider = FutureProvider.autoDispose
    .family<List<FacilityReview>, String>(
      (ref, id) => ref.watch(parkingLotRepositoryProvider).reviews(id),
    );

/// One facility, by its public ID. Retry by invalidating it.
final parkingLotProvider = FutureProvider.autoDispose
    .family<ParkingLot, String>(
      (ref, id) => ref.watch(parkingLotRepositoryProvider).find(id),
    );
