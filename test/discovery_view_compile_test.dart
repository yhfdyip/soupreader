import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/discovery/views/discovery_explore_results_view.dart';
import 'package:soupreader/features/discovery/views/discovery_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';

void main() {
  test('DiscoveryView 编译可用', () {
    expect(() => const DiscoveryView(), returnsNormally);
  });

  test('DiscoveryExploreResultsView 编译可用', () {
    const source = BookSource(
      bookSourceName: '示例源',
      bookSourceUrl: 'https://example.com',
    );
    expect(
      () => const DiscoveryExploreResultsView(
        source: source,
        exploreName: '发现分类',
        exploreUrl: 'https://example.com/explore',
      ),
      returnsNormally,
    );
  });
}
