import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/views/search_book_info_view.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  test('SearchBookInfoView 编译可用', () {
    expect(
      () => const SearchBookInfoView(
        result: SearchResult(
          name: '示例书',
          author: '示例作者',
          coverUrl: '',
          intro: '',
          lastChapter: '',
          bookUrl: 'https://example.com/book',
          sourceUrl: 'https://example.com/source',
          sourceName: '示例源',
        ),
      ),
      returnsNormally,
    );
  });
}
