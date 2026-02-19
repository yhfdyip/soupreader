/// RSS 文章列表“继续加载”按钮判定（对齐 legado LoadMoreView 语义）。
class RssArticleLoadMoreHelper {
  const RssArticleLoadMoreHelper._();

  static bool shouldShowManualLoadMore({
    required bool isLoading,
    required bool hasMore,
    required int articleCount,
  }) {
    return !isLoading && hasMore && articleCount > 0;
  }
}
