import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:app/features/search/data/models/location_suggestion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

class SearchRepository {
  const SearchRepository(this._api);

  final ApiClient _api;

  /// Locations the customer can choose as the centre of a parking search.
  Future<List<LocationSuggestion>> searchLocations(String query) async {
    final response = await _api.get('/places/search', query: {'query': query});
    final data = response['data'];
    if (data is! List) {
      throw const ApiException(code: ApiErrorCode.unknown);
    }

    if (data.any((item) => item is! Map<String, dynamic>)) {
      throw const ApiException(code: ApiErrorCode.unknown);
    }

    try {
      return data
          .cast<Map<String, dynamic>>()
          .map(LocationSuggestion.fromJson)
          .toList();
    } on FormatException {
      throw const ApiException(code: ApiErrorCode.unknown);
    } on TypeError {
      throw const ApiException(code: ApiErrorCode.unknown);
    }
  }

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
    final data = envelope['data'];
    if (data is! List || data.any((item) => item is! Map)) {
      throw const ApiException(code: ApiErrorCode.unknown);
    }

    try {
      return NumberedPage.fromJson(envelope, ParkingLotSummary.fromJson);
    } on FormatException {
      throw const ApiException(code: ApiErrorCode.unknown);
    } on TypeError {
      throw const ApiException(code: ApiErrorCode.unknown);
    }
  }
}
