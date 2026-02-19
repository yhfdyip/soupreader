import 'dart:collection';

import '../models/rss_source.dart';
import 'rss_source_filter_helper.dart';

enum RssSourceQueryMode {
  all,
  enabled,
  disabled,
  login,
  noGroup,
  group,
  search,
}

class RssSourceQueryIntent {
  const RssSourceQueryIntent({
    required this.mode,
    required this.rawQuery,
    this.keyword = '',
  });

  final RssSourceQueryMode mode;
  final String rawQuery;
  final String keyword;
}

/// RSS 源管理视图辅助（对齐 legado `RssSourceActivity` + `RssSourceViewModel` 语义）
class RssSourceManageHelper {
  const RssSourceManageHelper._();

  static const String groupPrefix = 'group:';

  static RssSourceQueryIntent parseQueryIntent(
    String? query, {
    String enabledLabel = '启用',
    String disabledLabel = '禁用',
    String needLoginLabel = '需登录',
    String noGroupLabel = '未分组',
  }) {
    final normalized = (query ?? '').trim();
    if (normalized.isEmpty) {
      return const RssSourceQueryIntent(
        mode: RssSourceQueryMode.all,
        rawQuery: '',
      );
    }
    if (normalized == enabledLabel) {
      return RssSourceQueryIntent(
        mode: RssSourceQueryMode.enabled,
        rawQuery: normalized,
      );
    }
    if (normalized == disabledLabel) {
      return RssSourceQueryIntent(
        mode: RssSourceQueryMode.disabled,
        rawQuery: normalized,
      );
    }
    if (normalized == needLoginLabel) {
      return RssSourceQueryIntent(
        mode: RssSourceQueryMode.login,
        rawQuery: normalized,
      );
    }
    if (normalized == noGroupLabel) {
      return RssSourceQueryIntent(
        mode: RssSourceQueryMode.noGroup,
        rawQuery: normalized,
      );
    }
    if (normalized.startsWith(groupPrefix)) {
      return RssSourceQueryIntent(
        mode: RssSourceQueryMode.group,
        rawQuery: normalized,
        keyword: normalized.substring(groupPrefix.length).trim(),
      );
    }
    return RssSourceQueryIntent(
      mode: RssSourceQueryMode.search,
      rawQuery: normalized,
      keyword: normalized,
    );
  }

  static List<RssSource> applyQueryIntent(
    Iterable<RssSource> sources,
    RssSourceQueryIntent intent,
  ) {
    switch (intent.mode) {
      case RssSourceQueryMode.all:
        return RssSourceFilterHelper.sortByCustomOrder(sources);
      case RssSourceQueryMode.enabled:
        return RssSourceFilterHelper.filterEnabled(sources);
      case RssSourceQueryMode.disabled:
        return RssSourceFilterHelper.filterDisabled(sources);
      case RssSourceQueryMode.login:
        return RssSourceFilterHelper.filterLogin(sources);
      case RssSourceQueryMode.noGroup:
        return RssSourceFilterHelper.filterNoGroup(sources);
      case RssSourceQueryMode.group:
        return RssSourceFilterHelper.filterGroupSearch(sources, intent.keyword);
      case RssSourceQueryMode.search:
        return RssSourceFilterHelper.filterSearch(sources, intent.keyword);
    }
  }

  static List<RssSource> addGroupToNoGroupSources({
    required Iterable<RssSource> allSources,
    required String group,
  }) {
    final groupName = group.trim();
    if (groupName.isEmpty) return const <RssSource>[];
    final updates = <RssSource>[];
    for (final source in allSources) {
      final raw = source.sourceGroup?.trim();
      if (raw != null && raw.isNotEmpty) continue;
      updates.add(source.copyWith(sourceGroup: groupName));
    }
    return updates;
  }

  static List<RssSource> renameGroup({
    required Iterable<RssSource> allSources,
    required String oldGroup,
    required String? newGroup,
  }) {
    final oldName = oldGroup.trim();
    if (oldName.isEmpty) return const <RssSource>[];
    final newName = (newGroup ?? '').trim();
    final updates = <RssSource>[];

    for (final source in allSources) {
      final tokens = LinkedHashSet<String>.from(
        RssSource.splitGroups(source.sourceGroup),
      );
      if (!tokens.contains(oldName)) continue;
      tokens.remove(oldName);
      if (newName.isNotEmpty) {
        tokens.add(newName);
      }
      updates.add(
        source.copyWith(sourceGroup: tokens.join(',')),
      );
    }
    return updates;
  }

  static List<RssSource> removeGroup({
    required Iterable<RssSource> allSources,
    required String group,
  }) {
    final name = group.trim();
    if (name.isEmpty) return const <RssSource>[];
    final updates = <RssSource>[];

    for (final source in allSources) {
      final tokens = LinkedHashSet<String>.from(
        RssSource.splitGroups(source.sourceGroup),
      );
      if (!tokens.contains(name)) continue;
      tokens.remove(name);
      updates.add(
        source.copyWith(sourceGroup: tokens.join(',')),
      );
    }
    return updates;
  }

  static RssSource moveToTop({
    required RssSource source,
    required int minOrder,
  }) {
    return source.copyWith(customOrder: minOrder - 1);
  }

  static RssSource moveToBottom({
    required RssSource source,
    required int maxOrder,
  }) {
    return source.copyWith(customOrder: maxOrder + 1);
  }
}
