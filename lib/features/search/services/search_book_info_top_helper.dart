import '../../bookshelf/models/book.dart';

/// 详情页置顶辅助（对齐 legado `BookInfoViewModel.topBook`）。
class SearchBookInfoTopHelper {
  const SearchBookInfoTopHelper._();

  /// legado 语义：置顶时同步更新最近阅读时间，确保“最近阅读/最近更新”排序可见。
  static Book buildPinnedBook({
    required Book book,
    required DateTime now,
  }) {
    return book.copyWith(
      lastReadTime: now,
      addedTime: now,
    );
  }
}
