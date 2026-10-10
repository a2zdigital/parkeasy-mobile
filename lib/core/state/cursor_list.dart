import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/pagination.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A list fetched page by page with a cursor, and everything a screen
/// needs to draw it honestly: first load, empty, error, more loading, and
/// a failed "more" that keeps what is already shown.
class CursorListState<T> {
  const CursorListState({
    this.items = const [],
    this.isLoading = false,
    this.failure,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<T> items;

  /// The first page is loading and there is nothing to show yet.
  final bool isLoading;

  /// The first page could not be loaded.
  final ApiException? failure;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  /// A later page, or a refresh, failed; the shown items stay.
  final ApiException? loadMoreFailure;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;
}

/// The loading logic shared by every cursor-paged list. A feature
/// subclasses it and says only how to fetch a page.
///
/// To reload after something changed, invalidate the provider. Anything
/// the subclass `watch`es in [fetchPage]'s inputs should be watched in
/// [watchInputs], so a changed filter starts the list again.
abstract class CursorListNotifier<T>
    extends AutoDisposeNotifier<CursorListState<T>> {
  int _generation = 0;
  bool _disposed = false;

  Future<CursorPage<T>> fetchPage(String? cursor);

  /// Override to `ref.watch` the filters this list depends on.
  void watchInputs() {}

  @override
  CursorListState<T> build() {
    watchInputs();
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() {
      if (!_disposed) load();
    });
    return CursorListState<T>(isLoading: true);
  }

  /// Loads the first page. Also pull-to-refresh and "Try again"; while
  /// refreshing, the shown list stays.
  Future<void> load() async {
    final generation = ++_generation;
    final hadItems = state.items.isNotEmpty;
    state = CursorListState<T>(
      items: state.items,
      isLoading: !hadItems,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );

    try {
      final page = await fetchPage(null);
      if (_disposed || generation != _generation) return;
      state = CursorListState<T>(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (failure) {
      if (_disposed || generation != _generation) return;
      state = CursorListState<T>(
        items: state.items,
        failure: hadItems ? null : failure,
        loadMoreFailure: hadItems ? failure : null,
        nextCursor: state.nextCursor,
        hasMore: state.hasMore,
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (cursor == null) return;

    final generation = _generation;
    state = CursorListState<T>(
      items: state.items,
      nextCursor: cursor,
      hasMore: true,
      isLoadingMore: true,
    );

    try {
      final page = await fetchPage(cursor);
      if (_disposed || generation != _generation) return;
      state = CursorListState<T>(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (failure) {
      if (_disposed || generation != _generation) return;
      state = CursorListState<T>(
        items: state.items,
        nextCursor: cursor,
        hasMore: true,
        loadMoreFailure: failure,
      );
    }
  }

  /// Replaces the shown items without a request, for a change the screen
  /// already knows about (an item marked read).
  void replaceItems(List<T> Function(List<T> items) update) {
    state = CursorListState<T>(
      items: update(state.items),
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
  }
}
