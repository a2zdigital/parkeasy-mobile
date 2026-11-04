import 'package:app/core/api/api_exception.dart';
import 'package:app/features/search/data/models/location_suggestion.dart';
import 'package:app/features/search/data/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final placeSearchProvider =
    NotifierProvider<PlaceSearchNotifier, PlaceSearchState>(
      PlaceSearchNotifier.new,
    );

class PlaceSearchState {
  const PlaceSearchState({
    this.query = '',
    this.suggestions = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.isInvalidQuery = false,
    this.failure,
  });

  final String query;
  final List<LocationSuggestion> suggestions;
  final bool isLoading;
  final bool hasSearched;
  final bool isInvalidQuery;
  final ApiException? failure;
}

class PlaceSearchNotifier extends Notifier<PlaceSearchState> {
  int _generation = 0;
  bool _disposed = false;

  @override
  PlaceSearchState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const PlaceSearchState();
  }

  void updateQuery(String query) {
    _generation++;
    state = PlaceSearchState(query: query);
  }

  void clear() {
    _generation++;
    state = const PlaceSearchState();
  }

  Future<void> search(String query) async {
    final generation = ++_generation;
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      state = PlaceSearchState(
        query: query,
        hasSearched: true,
        isInvalidQuery: true,
      );
      return;
    }

    state = PlaceSearchState(query: query, isLoading: true, hasSearched: true);

    try {
      final suggestions = await ref
          .read(searchRepositoryProvider)
          .searchLocations(normalizedQuery);
      if (_disposed || generation != _generation) return;

      state = PlaceSearchState(
        query: query,
        suggestions: suggestions,
        hasSearched: true,
      );
    } on ApiException catch (failure) {
      if (_disposed || generation != _generation) return;

      state = PlaceSearchState(
        query: query,
        hasSearched: true,
        failure: failure,
      );
    }
  }
}
