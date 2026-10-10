import 'package:app/core/api/api_exception.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingsProvider =
    NotifierProvider.autoDispose<BookingsNotifier, BookingsState>(
      BookingsNotifier.new,
    );

class BookingsState {
  const BookingsState({
    this.items = const [],
    this.isLoading = false,
    this.failure,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<Booking> items;
  final bool isLoading;
  final ApiException? failure;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final ApiException? loadMoreFailure;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;
}

/// The customer's bookings, newest first. Invalidated whenever a booking
/// is created or changed, so the list is never patched by hand.
class BookingsNotifier extends AutoDisposeNotifier<BookingsState> {
  int _generation = 0;
  bool _disposed = false;

  @override
  BookingsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() {
      if (!_disposed) load();
    });
    return const BookingsState(isLoading: true);
  }

  Future<void> load() async {
    final generation = ++_generation;
    final hadItems = state.items.isNotEmpty;
    state = BookingsState(
      items: state.items,
      isLoading: !hadItems,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );

    try {
      final page = await ref.read(bookingRepositoryProvider).mine();
      if (_disposed || generation != _generation) return;
      state = BookingsState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (failure) {
      if (_disposed || generation != _generation) return;
      state = BookingsState(
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
    state = BookingsState(
      items: state.items,
      nextCursor: cursor,
      hasMore: true,
      isLoadingMore: true,
    );

    try {
      final page = await ref
          .read(bookingRepositoryProvider)
          .mine(cursor: cursor);
      if (_disposed || generation != _generation) return;
      state = BookingsState(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (failure) {
      if (_disposed || generation != _generation) return;
      state = BookingsState(
        items: state.items,
        nextCursor: cursor,
        hasMore: true,
        loadMoreFailure: failure,
      );
    }
  }
}
