import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

class SearchRepository {
  const SearchRepository(this._api);

  final ApiClient _api;

  /// Bookable facilities around a point, nearest first.
  Future<NumberedPage<ParkingLotSummary>> near({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? vehicleType,
    int page = 1,
  }) async {
    final envelope = await _api.get(
      '/parking-lots',
      query: {
        'lat': latitude,
        'lng': longitude,
        'radius_km': radiusKm,
        'filter[vehicle_type]': vehicleType,
        'page': page,
      },
    );
    return NumberedPage.fromJson(envelope, ParkingLotSummary.fromJson);
  }
}
