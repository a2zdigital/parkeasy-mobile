import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/parking_lot/data/models/parking_lot_summary.dart';
import 'package:app/features/search/data/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exploreProvider = NotifierProvider<ExploreNotifier, ExploreState>(
  ExploreNotifier.new,
);

class ExploreState {
  const ExploreState({
    this.items = const [],
    this.isLoading = false,
    this.failure,
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailure,
    this.vehicleType,
    this.vehicleTypes = const [],
  });

  final List<ParkingLotSummary> items;

  /// The first page is loading and there is nothing to show yet.
  final bool isLoading;

  /// The first page could not be loaded.
  final ApiException? failure;

  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  /// A later page could not be loaded; what is already shown stays.
  final ApiException? loadMoreFailure;

  /// The selected vehicle-type code, or null for all.
  final String? vehicleType;

  /// The vehicle types seen in unfiltered results, offered as filters.
  final List<CodeName> vehicleTypes;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;
}

class ExploreNotifier extends Notifier<ExploreState> {
  // Each new search invalidates the answers of the ones before it, so a
  // slow response can never overwrite a newer one.
  int _generation = 0;

  @override
  ExploreState build() {
    Future.microtask(load);
    return const ExploreState(isLoading: true);
  }

  /// Loads the first page for the current filter. Also the pull-to-refresh
  /// and "Try again" action; while refreshing, the shown list stays.
  Future<void> load() async {
    final generation = ++_generation;
    final hadItems = state.items.isNotEmpty;
    state = ExploreState(
      items: state.items,
      isLoading: !hadItems,
      page: state.page,
      hasMore: state.hasMore,
      vehicleType: state.vehicleType,
      vehicleTypes: state.vehicleTypes,
    );

    try {
      final result = await _fetch(1);
      if (generation != _generation) return;

      state = ExploreState(
        items: result.items,
        page: result.page,
        hasMore: result.hasMore,
        vehicleType: state.vehicleType,
        vehicleTypes: state.vehicleType == null
            ? _vehicleTypesIn(result.items)
            : state.vehicleTypes,
      );
    } on ApiException catch (failure) {
      if (generation != _generation) return;

      state = ExploreState(
        // A failed refresh keeps the list; a failed first load shows the error.
        items: state.items,
        failure: hadItems ? null : failure,
        loadMoreFailure: hadItems ? failure : null,
        page: state.page,
        hasMore: state.hasMore,
        vehicleType: state.vehicleType,
        vehicleTypes: state.vehicleTypes,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final generation = _generation;
    state = ExploreState(
      items: state.items,
      page: state.page,
      hasMore: state.hasMore,
      isLoadingMore: true,
      vehicleType: state.vehicleType,
      vehicleTypes: state.vehicleTypes,
    );

    try {
      final result = await _fetch(state.page + 1);
      if (generation != _generation) return;

      state = ExploreState(
        items: [...state.items, ...result.items],
        page: result.page,
        hasMore: result.hasMore,
        vehicleType: state.vehicleType,
        vehicleTypes: state.vehicleTypes,
      );
    } on ApiException catch (failure) {
      if (generation != _generation) return;

      state = ExploreState(
        items: state.items,
        page: state.page,
        hasMore: state.hasMore,
        loadMoreFailure: failure,
        vehicleType: state.vehicleType,
        vehicleTypes: state.vehicleTypes,
      );
    }
  }

  /// Filters by a vehicle-type code; null shows all.
  Future<void> selectVehicleType(String? code) async {
    if (code == state.vehicleType) return;

    state = ExploreState(
      isLoading: true,
      vehicleType: code,
      vehicleTypes: state.vehicleTypes,
    );
    await load();
  }

  Future<({List<ParkingLotSummary> items, int page, bool hasMore})> _fetch(
    int page,
  ) async {
    final config = ref.read(appConfigProvider);
    final result = await ref
        .read(searchRepositoryProvider)
        .near(
          latitude: config.searchOrigin.latitude,
          longitude: config.searchOrigin.longitude,
          radiusKm: config.searchRadiusKm,
          vehicleType: state.vehicleType,
          page: page,
        );
    return (items: result.items, page: result.page, hasMore: result.hasMore);
  }

  static List<CodeName> _vehicleTypesIn(List<ParkingLotSummary> items) {
    final byCode = <String, CodeName>{};
    for (final item in items) {
      for (final pool in item.pools) {
        byCode.putIfAbsent(pool.vehicleType.code, () => pool.vehicleType);
      }
    }
    return byCode.values.toList();
  }
}
