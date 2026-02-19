/// 搜索分页“继续加载”按钮判定（对齐 legado SearchActivity 的播放键语义）：
/// - 仅在当前不处于搜索中；
/// - 且本次会话仍有下一页；
/// - 且已有结果可继续翻页；
/// 才显示手动继续入口。
class SearchLoadMoreHelper {
  const SearchLoadMoreHelper._();

  static bool shouldShowManualLoadMore({
    required bool isSearching,
    required bool hasMore,
    required int resultCount,
  }) {
    return !isSearching && hasMore && resultCount > 0;
  }
}
