import 'dart:convert';

import '../../bookshelf/models/book.dart';

/// 详情页分享载荷辅助（对齐 legado `BookInfoActivity.menu_share_it`）。
class SearchBookInfoShareHelper {
  const SearchBookInfoShareHelper._();

  /// legado 语义：`bookUrl#bookJson`。
  static String buildPayload(Book book) {
    final bookUrl = (book.bookUrl ?? '').trim();
    final bookJson = jsonEncode(book.toJson());
    return '$bookUrl#$bookJson';
  }
}
