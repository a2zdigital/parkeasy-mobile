import 'package:app/core/api/pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String name(Map<String, dynamic> item) => item['name'] as String;

  test('CursorPage reads items and the cursor', () {
    final page = CursorPage.fromJson({
      'data': [
        {'name': 'a'},
        {'name': 'b'},
      ],
      'meta': {'per_page': 20, 'next_cursor': 'abc', 'has_more': true},
    }, name);

    expect(page.items, ['a', 'b']);
    expect(page.nextCursor, 'abc');
    expect(page.hasMore, isTrue);
  });

  test('CursorPage treats a missing meta as the last page', () {
    final page = CursorPage.fromJson({'data': <Object?>[]}, name);

    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
    expect(page.hasMore, isFalse);
  });

  test('NumberedPage knows whether more pages exist', () {
    Map<String, dynamic> body(int page) => {
      'data': [
        {'name': 'a'},
      ],
      'meta': {'page': page, 'per_page': 20, 'total': 41, 'last_page': 3},
    };

    expect(NumberedPage.fromJson(body(1), name).hasMore, isTrue);
    expect(NumberedPage.fromJson(body(3), name).hasMore, isFalse);
    expect(NumberedPage.fromJson(body(1), name).total, 41);
  });
}
