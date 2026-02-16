import 'package:pinyin/pinyin.dart';

import '../../source/models/book_source.dart';
import 'search_scope.dart';

/// 搜索范围分组处理（对齐 legado BookSourceDao.dealGroups）：
/// - 只统计启用书源
/// - 按 `[,;，；]` 拆分分组
/// - 去空与去重
/// - 排序输出
class SearchScopeGroupHelper {
  const SearchScopeGroupHelper._();

  static final Map<String, String> _sortKeyCache = <String, String>{};
  static const int _sortKeyCacheLimit = 512;

  static List<String> enabledGroupsFromSources(Iterable<BookSource> sources) {
    final rawGroups = <String>[];
    for (final source in sources) {
      if (source.enabled != true) continue;
      final raw = source.bookSourceGroup?.trim();
      if (raw == null || raw.isEmpty) continue;
      rawGroups.add(raw);
    }
    return dealGroups(rawGroups);
  }

  static List<String> dealGroups(Iterable<String> rawGroups) {
    final groups = <String>{};
    for (final raw in rawGroups) {
      for (final group in SearchScope.splitSourceGroups(raw)) {
        groups.add(group);
      }
    }
    final sorted = groups.toList(growable: false)..sort(cnCompareLikeLegado);
    return sorted;
  }

  /// legado `cnCompare` 的 Dart 等价实现（近似）：
  /// - 中文字符转无声调拼音后比较
  /// - 其余字符按小写原文比较
  /// - 拼音键相同时回退原文比较，保证排序稳定
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
    final isUpper = code >= 65 && code <= 90;
    final isLower = code >= 97 && code <= 122;
    return isUpper || isLower;
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
