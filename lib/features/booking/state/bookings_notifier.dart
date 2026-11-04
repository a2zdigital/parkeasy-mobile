import 'package:app/core/api/api_exception.dart';
import 'package:app/core/api/pagination.dart';
import 'package:app/features/booking/data/booking_repository.dart';
import 'package:app/features/booking/data/models/booking.dart';
import 'package:app/features/booking/data/models/booking_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CustomerBookingTab { upcoming, past }

final customerBookingTabProvider =
    StateProvider.autoDispose<CustomerBookingTab>(
      (ref) => CustomerBookingTab.upcoming,
    );

final bookingsProvider =
    NotifierProvider.autoDispose<BookingsNotifier, BookingsState>(
      BookingsNotifier.new,
    );

class BookingsState {
  const BookingsState({
    this.items = const [],
    this.isLoading = false,
    this.failure,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<Booking> items;
  final bool isLoading;
  final ApiException? failure;
  final bool hasMore;
  final bool isLoadingMore;
  final ApiException? loadMoreFailure;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;
}

/// The customer's bookings, filtered by API status and merged newest first.
class BookingsNotifier extends AutoDisposeNotifier<BookingsState> {
  static const _upcomingStatuses = [
    BookingStatus.pendingApproval,
    BookingStatus.awaitingPayment,
    BookingStatus.confirmed,
  ];
  static const _pastStatuses = [
    BookingStatus.rejected,
    BookingStatus.cancelled,
    BookingStatus.completed,
    BookingStatus.expired,
    BookingStatus.noShow,
  ];

  int _generation = 0;
  bool _disposed = false;
  late CustomerBookingTab _tab;
  late List<BookingStatus> _statuses;
  final Map<BookingStatus, String> _cursors = {};
  final Set<BookingStatus> _hasMoreStatuses = {};
  final Set<BookingStatus> _failedStatuses = {};

  @override
  BookingsState build() {
    _tab = ref.watch(customerBookingTabProvider);
    _statuses = switch (_tab) {
      CustomerBookingTab.upcoming => _upcomingStatuses,
      CustomerBookingTab.past => _pastStatuses,
    };
    _generation++;
    _cursors.clear();
    _hasMoreStatuses.clear();
    _failedStatuses.clear();
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() {
      if (!_disposed) load();
    });
    return const BookingsState(isLoading: true);
  }

  Future<void> load() async {
    final generation = ++_generation;
    final previousItems = state.items;
    final hadItems = previousItems.isNotEmpty;
    state = BookingsState(
      items: previousItems,
      isLoading: !hadItems,
      hasMore: _hasMoreStatuses.isNotEmpty || _failedStatuses.isNotEmpty,
    );

    final results = await _fetchPages(_statuses, useCursors: false);
    if (_disposed || generation != _generation) return;

    final failed = results.where((result) => result.failure != null).toList();
    if (failed.isNotEmpty) {
      _failedStatuses
        ..clear()
        ..addAll(failed.map((result) => result.status));
      state = BookingsState(
        items: previousItems,
        failure: hadItems ? null : failed.first.failure,
        hasMore: _hasMoreStatuses.isNotEmpty || _failedStatuses.isNotEmpty,
        loadMoreFailure: hadItems ? failed.first.failure : null,
      );
      return;
    }

    _cursors.clear();
    _hasMoreStatuses.clear();
    _failedStatuses.clear();
    final pages = <CursorPage<Booking>>[];
    for (final result in results) {
      final page = result.pageOrThrow;
      pages.add(page);
      final cursor = page.nextCursor;
      if (page.hasMore && cursor != null) {
        _cursors[result.status] = cursor;
        _hasMoreStatuses.add(result.status);
      }
    }
    state = BookingsState(
      items: _mergePages(pages),
      hasMore: _hasMoreStatuses.isNotEmpty,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final statuses = _failedStatuses.isNotEmpty
        ? _failedStatuses.toList()
        : _statuses.where(_hasMoreStatuses.contains).toList();
    if (statuses.isEmpty) return;

    final generation = _generation;
    state = BookingsState(
      items: state.items,
      hasMore: true,
      isLoadingMore: true,
    );
    final results = await _fetchPages(statuses, useCursors: true);
    if (_disposed || generation != _generation) return;

    final pages = <CursorPage<Booking>>[];
    final failures = <ApiException>[];
    for (final result in results) {
      final failure = result.failure;
      if (failure != null) {
        failures.add(failure);
        _failedStatuses.add(result.status);
        continue;
      }

      _failedStatuses.remove(result.status);
      final page = result.pageOrThrow;
      pages.add(page);
      final cursor = page.nextCursor;
      if (page.hasMore && cursor != null) {
        _cursors[result.status] = cursor;
        _hasMoreStatuses.add(result.status);
      } else {
        _cursors.remove(result.status);
        _hasMoreStatuses.remove(result.status);
      }
    }

    state = BookingsState(
      items: _mergePages(pages, existing: state.items),
      hasMore: _hasMoreStatuses.isNotEmpty || _failedStatuses.isNotEmpty,
      loadMoreFailure: failures.isEmpty ? null : failures.first,
    );
  }

  Future<List<_BookingPageResult>> _fetchPages(
    Iterable<BookingStatus> statuses, {
    required bool useCursors,
  }) async {
    final repository = ref.read(bookingRepositoryProvider);
    return Future.wait(
      statuses.map((status) async {
        try {
          final page = await repository.mine(
            status: status,
            cursor: useCursors ? _cursors[status] : null,
          );
          return _BookingPageResult.success(status, page);
        } on ApiException catch (failure) {
          return _BookingPageResult.failed(status, failure);
        }
      }),
    );
  }

  List<Booking> _mergePages(
    Iterable<CursorPage<Booking>> pages, {
    List<Booking> existing = const [],
  }) {
    final byId = <String, Booking>{for (final item in existing) item.id: item};
    for (final page in pages) {
      for (final item in page.items) {
        byId[item.id] = item;
      }
    }
    return byId.values.toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
  }
}

class _BookingPageResult {
  const _BookingPageResult.success(this.status, this.page) : failure = null;
  const _BookingPageResult.failed(this.status, this.failure) : page = null;

  final BookingStatus status;
  final CursorPage<Booking>? page;
  final ApiException? failure;

  CursorPage<Booking> get pageOrThrow {
    final page = this.page;
    if (page == null) {
      throw StateError('A failed booking page has no page.');
    }
    return page;
  }
}
