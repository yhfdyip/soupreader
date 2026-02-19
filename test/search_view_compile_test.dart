import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/views/search_view.dart';

void main() {
  test('SearchView 编译可用', () {
    expect(
      () => const SearchView(),
      returnsNormally,
    );
    expect(
      () => const SearchView.scoped(
        sourceUrls: <String>['https://example.com/source'],
      ),
      returnsNormally,
    );
  });
}
