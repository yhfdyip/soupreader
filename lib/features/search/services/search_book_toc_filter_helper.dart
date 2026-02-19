import '../../source/services/rule_parser_engine.dart';

/// 搜索详情目录检索辅助（对齐 legado `BookChapterDao.search(title like ...)`）：
/// - 目录检索仅基于章节原始标题字段；
/// - 展示标题（简繁转换/替换规则）仅用于渲染，不参与过滤；
/// - 倒序在过滤后执行。
class SearchBookTocFilterHelper {
  const SearchBookTocFilterHelper._();

  static List<MapEntry<int, TocItem>> filterEntries({
    required List<TocItem> toc,
    required String rawQuery,
    required bool reversed,
  }) {
    final query = rawQuery.trim().toLowerCase();
    var entries = toc.asMap().entries.toList(growable: false);
    if (query.isNotEmpty) {
      entries = entries
          .where((entry) => entry.value.name.toLowerCase().contains(query))
          .toList(growable: false);
    }
    if (reversed) {
      entries = entries.reversed.toList(growable: false);
    }
    return entries;
  }
}
