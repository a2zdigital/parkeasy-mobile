/// One page of a list ordered by time, fetched with a cursor.
class CursorPage<T> {
  const CursorPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  /// Reads `{ "data": [...], "meta": { "next_cursor", "has_more" } }`.
  factory CursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItem,
  ) {
    final meta = json['meta'];
    final nextCursor = meta is Map ? meta['next_cursor'] : null;
    return CursorPage(
      items: _items(json['data'], fromItem),
      nextCursor: nextCursor is String ? nextCursor : null,
      hasMore: meta is Map && meta['has_more'] == true,
    );
  }

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

/// One page of a list fetched by page number (facility search).
class NumberedPage<T> {
  const NumberedPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  /// Reads `{ "data": [...], "meta": { "page", "last_page", "total" } }`.
  factory NumberedPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItem,
  ) {
    final meta = json['meta'];
    int read(String key, int fallback) {
      final value = meta is Map ? meta[key] : null;
      return value is int ? value : fallback;
    }

    final items = _items(json['data'], fromItem);
    return NumberedPage(
      items: items,
      page: read('page', 1),
      lastPage: read('last_page', 1),
      total: read('total', items.length),
    );
  }

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

List<T> _items<T>(
  Object? data,
  T Function(Map<String, dynamic> item) fromItem,
) {
  if (data is! List) return const [];
  return [
    for (final item in data)
      if (item is Map) fromItem(Map<String, dynamic>.from(item)),
  ];
}
