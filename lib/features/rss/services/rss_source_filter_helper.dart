import 'package:pinyin/pinyin.dart';

import '../models/rss_source.dart';

/// RSS 订阅源筛选辅助（对齐 legado `RssSourceDao` 语义）
class RssSourceFilterHelper {
  const RssSourceFilterHelper._();

  static final Map<String, String> _sortKeyCache = <String, String>{};
  static const int _sortKeyCacheLimit = 512;

  static List<RssSource> sortByCustomOrder(Iterable<RssSource> sources) {
    final list = sources.toList(growable: false);
    list.sort((left, right) {
      final orderCompare = left.customOrder.compareTo(right.customOrder);
      if (orderCompare != 0) return orderCompare;
      return left.sourceUrl.compareTo(right.sourceUrl);
    });
    return list;
  }

  static List<RssSource> filterSearch(
    Iterable<RssSource> sources,
    String key,
  ) {
    final query = key.trim();
    if (query.isEmpty) return sortByCustomOrder(sources);
    return sortByCustomOrder(sources).where((source) {
      return _contains(source.sourceName, query) ||
          _contains(source.sourceUrl, query) ||
          _contains(source.sourceGroup, query) ||
          _contains(source.sourceComment, query);
    }).toList(growable: false);
  }

  static List<RssSource> filterGroupSearch(
    Iterable<RssSource> sources,
    String group,
  ) {
    final key = group.trim();
    if (key.isEmpty) return sortByCustomOrder(sources);
    return sortByCustomOrder(sources)
        .where((source) => containsGroupToken(source.sourceGroup, key))
        .toList(growable: false);
  }

  static List<RssSource> filterEnabled(
    Iterable<RssSource> sources, {
    String? searchKey,
  }) {
    final key = searchKey?.trim();
    final filtered = sortByCustomOrder(sources).where((source) {
      if (!source.enabled) return false;
      if (key == null || key.isEmpty) return true;
      return _contains(source.sourceName, key) ||
          _contains(source.sourceGroup, key) ||
          _contains(source.sourceUrl, key) ||
          _contains(source.sourceComment, key);
    });
    return filtered.toList(growable: false);
  }

  static List<RssSource> filterDisabled(Iterable<RssSource> sources) {
    return sortByCustomOrder(sources)
        .where((source) => !source.enabled)
        .toList(growable: false);
  }

  static List<RssSource> filterEnabledByGroup(
    Iterable<RssSource> sources,
    String group,
  ) {
    final key = group.trim();
    if (key.isEmpty) return filterEnabled(sources);
    return sortByCustomOrder(sources).where((source) {
      return source.enabled && containsGroupToken(source.sourceGroup, key);
    }).toList(growable: false);
  }

  static List<RssSource> filterLogin(Iterable<RssSource> sources) {
    return sortByCustomOrder(sources).where((source) {
      final loginUrl = source.loginUrl?.trim();
      return loginUrl != null && loginUrl.isNotEmpty;
    }).toList(growable: false);
  }

  static List<RssSource> filterNoGroup(Iterable<RssSource> sources) {
    return sortByCustomOrder(sources).where((source) {
      final raw = source.sourceGroup;
      if (raw == null) return true;
      final text = raw.trim();
      if (text.isEmpty) return true;
      return text.contains('未分组');
    }).toList(growable: false);
  }

  static bool containsGroupToken(String? sourceGroup, String key) {
    final groupKey = key.trim();
    if (groupKey.isEmpty) return false;
    final tokens = RssSource.splitGroups(sourceGroup);
    return tokens.contains(groupKey);
  }

  static List<String> dealGroups(Iterable<String> rawGroups) {
    final groups = <String>{};
    for (final raw in rawGroups) {
      for (final group in RssSource.splitGroups(raw)) {
        groups.add(group);
      }
    }
    final sorted = groups.toList(growable: false)..sort(cnCompareLikeLegado);
    return sorted;
  }

  static List<String> allGroupsFromSources(
    Iterable<RssSource> sources, {
    bool enabledOnly = false,
  }) {
    final rawGroups = <String>[];
    for (final source in sources) {
      if (enabledOnly && !source.enabled) continue;
      final raw = source.sourceGroup?.trim();
      if (raw == null || raw.isEmpty) continue;
      rawGroups.add(raw);
    }
    return dealGroups(rawGroups);
  }

  static int cnCompareLikeLegado(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left == right) return 0;

    final leftType = _sortType(left);
    final rightType = _sortType(right);
    final typeCompare = leftType.compareTo(rightType);
    if (typeCompare != 0) return typeCompare;

    final leftKey = _toCnSortKey(left);
    final rightKey = _toCnSortKey(right);
    final keyCompare = leftKey.compareTo(rightKey);
    if (keyCompare != 0) return keyCompare;
    return left.compareTo(right);
  }

  static bool _contains(String? value, String key) {
    if (value == null) return false;
    return value.contains(key);
  }

  static int _sortType(String value) {
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (_isDigit(char)) return 0;
      if (ChineseHelper.isChinese(char)) return 1;
      if (_isAsciiLetter(char)) return 2;
    }
    return 3;
  }

  static bool _isDigit(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isAsciiLetter(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static String _toCnSortKey(String value) {
    final cached = _sortKeyCache[value];
    if (cached != null) return cached;

    final result = PinyinHelper.getPinyinE(
      value,
      separator: '',
      defPinyin: value,
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();
    if (_sortKeyCache.length >= _sortKeyCacheLimit) {
      _sortKeyCache.remove(_sortKeyCache.keys.first);
    }
    _sortKeyCache[value] = result;
    return result;
  }
}
