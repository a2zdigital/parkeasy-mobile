import 'package:app/core/api/api_client.dart';
import 'package:app/core/providers.dart';
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
}
