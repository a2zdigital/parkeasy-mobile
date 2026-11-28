import 'package:app/core/api/api_client.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/parking_lot/data/models/facility_review.dart';
import 'package:app/features/parking_lot/data/models/parking_lot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final parkingLotRepositoryProvider = Provider<ParkingLotRepository>(
  (ref) => ParkingLotRepository(ref.watch(apiClientProvider)),
);

class ParkingLotRepository {
  const ParkingLotRepository(this._api);

  final ApiClient _api;

  Future<ParkingLot> find(String id) async => ParkingLot.fromJson(
    ApiClient.object(await _api.get('/parking-lots/$id')),
  );

  /// The newest visible reviews of a facility (anonymous).
  Future<List<FacilityReview>> reviews(String id, {int limit = 10}) async {
    final envelope = await _api.get(
      '/parking-lots/$id/ratings',
      query: {'per_page': limit},
    );
    final data = envelope['data'];
    return [
      if (data is List)
        for (final item in data)
          if (item is Map)
            FacilityReview.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
