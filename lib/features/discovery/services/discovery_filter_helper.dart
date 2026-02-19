import '../../source/models/book_source.dart';

/// 发现页筛选规则（对齐 legado ExploreFragment + BookSourceDao.flowExplore）。
class DiscoveryFilterHelper {
  const DiscoveryFilterHelper._();

  static List<BookSource> applyQueryFilter(
    List<BookSource> input,
    String query,
  ) {
    final raw = query.trim();
    if (raw.isEmpty) return input;

    // 对齐 legado：仅小写 `group:` 触发分组分支。
    if (raw.startsWith('group:')) {
      final key = raw.substring(6).trim();
      if (key.isEmpty) return input;
      return input
          .where(
              (source) => extractGroups(source.bookSourceGroup).contains(key))
          .toList(growable: false);
    }

    final q = raw.toLowerCase();
    return input.where((source) {
      final name = source.bookSourceName.toLowerCase();
      final group = (source.bookSourceGroup ?? '').toLowerCase();
      return name.contains(q) || group.contains(q);
    }).toList(growable: false);
  }

  static List<String> extractGroups(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const <String>[];
    return text
        .split(RegExp(r'[,;，；]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
