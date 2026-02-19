import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/services/search_load_more_helper.dart';

void main() {
  test('showManualLoadMore: 仅在非搜索中且有更多且已有结果时显示', () {
    expect(
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: false,
        hasMore: true,
        resultCount: 1,
      ),
      isTrue,
    );
  });

  test('showManualLoadMore: 搜索中不显示', () {
    expect(
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: true,
        hasMore: true,
        resultCount: 10,
      ),
      isFalse,
    );
  });

  test('showManualLoadMore: 无更多页不显示', () {
    expect(
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: false,
        hasMore: false,
        resultCount: 10,
      ),
      isFalse,
    );
  });

  test('showManualLoadMore: 无结果不显示', () {
    expect(
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: false,
        hasMore: true,
        resultCount: 0,
      ),
      isFalse,
    );
  });
}
