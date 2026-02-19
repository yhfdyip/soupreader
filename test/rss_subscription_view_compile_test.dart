import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/rss/views/rss_articles_placeholder_view.dart';
import 'package:soupreader/features/rss/views/rss_subscription_view.dart';

void main() {
  test('RssSubscriptionView 编译可用', () {
    expect(
      () => const RssSubscriptionView(),
      returnsNormally,
    );
  });

  test('RssArticlesPlaceholderView 与 RssReadPlaceholderView 编译可用', () {
    expect(
      () => const RssArticlesPlaceholderView(
        sourceName: '示例订阅源',
        sourceUrl: 'https://example.com/rss',
      ),
      returnsNormally,
    );
    expect(
      () => const RssReadPlaceholderView(
        title: '示例文章',
        origin: 'https://example.com/post/1',
      ),
      returnsNormally,
    );
  });
}
