import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/views/search_scope_picker_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';

void main() {
  test('SearchScopePickerView 编译可用', () {
    expect(
      () => SearchScopePickerView(
        sources: const <BookSource>[
          BookSource(
            bookSourceUrl: 'https://a.example.com',
            bookSourceName: '源A',
            bookSourceGroup: '男频',
            enabled: true,
          ),
          BookSource(
            bookSourceUrl: 'https://b.example.com',
            bookSourceName: '源B',
            bookSourceGroup: '女频',
            enabled: false,
          ),
        ],
        enabledSources: const <BookSource>[
          BookSource(
            bookSourceUrl: 'https://a.example.com',
            bookSourceName: '源A',
            bookSourceGroup: '男频',
            enabled: true,
          ),
        ],
      ),
      returnsNormally,
    );
  });
}
