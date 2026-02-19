/// 应用级设置（非阅读页内设置）
///
/// 目标：对标 Legado / 完全阅读器等同类产品的“设置”入口，把常用的全局开关
/// 统一收敛到一个可持久化、可迁移（备份/恢复）的模型里。
enum AppAppearanceMode {
  followSystem,
  light,
  dark,
}

enum BookshelfViewMode {
  grid,
  list,
}

enum BookshelfSortMode {
  recentRead,
  recentAdded,
  title,
  author,
}

enum SearchFilterMode {
  /// 历史兼容值：旧版本曾暴露“不过滤”入口。
  /// legado 仅有“精准搜索开关”，因此运行时会归一为 `normal`。
  none,
  normal,
  precise,
}

SearchFilterMode normalizeSearchFilterMode(SearchFilterMode mode) {
  return mode == SearchFilterMode.precise
      ? SearchFilterMode.precise
      : SearchFilterMode.normal;
}

class AppSettings {
  final AppAppearanceMode appearanceMode;
  final bool wifiOnlyDownload;
  final bool autoUpdateSources;

  final BookshelfViewMode bookshelfViewMode;
  final BookshelfSortMode bookshelfSortMode;
  final SearchFilterMode searchFilterMode;
  final int searchConcurrency;
  final int searchCacheRetentionDays;
  final String searchScope;
  final List<String> searchScopeSourceUrls;
  final bool searchShowCover;

  const AppSettings({
    this.appearanceMode = AppAppearanceMode.followSystem,
    this.wifiOnlyDownload = true,
    this.autoUpdateSources = true,
    this.bookshelfViewMode = BookshelfViewMode.grid,
    this.bookshelfSortMode = BookshelfSortMode.recentRead,
    this.searchFilterMode = SearchFilterMode.normal,
    this.searchConcurrency = 8,
    this.searchCacheRetentionDays = 5,
    this.searchScope = '',
    this.searchScopeSourceUrls = const <String>[],
    this.searchShowCover = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    AppAppearanceMode parseAppearanceMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == null) return AppAppearanceMode.followSystem;
      return AppAppearanceMode
          .values[index.clamp(0, AppAppearanceMode.values.length - 1)];
    }

    BookshelfViewMode parseViewMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == null) return BookshelfViewMode.grid;
      return BookshelfViewMode
          .values[index.clamp(0, BookshelfViewMode.values.length - 1)];
    }

    BookshelfSortMode parseSortMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == null) return BookshelfSortMode.recentRead;
      return BookshelfSortMode
          .values[index.clamp(0, BookshelfSortMode.values.length - 1)];
    }

    SearchFilterMode parseSearchFilterMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == SearchFilterMode.precise.index) {
        return SearchFilterMode.precise;
      }
      return SearchFilterMode.normal;
    }

    int parseIntWithDefault(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      final seen = <String>{};
      final out = <String>[];
      for (final item in raw) {
        final text = item.toString().trim();
        if (text.isEmpty) continue;
        if (!seen.add(text)) continue;
        out.add(text);
      }
      return out;
    }

    String parseString(dynamic raw) {
      if (raw == null) return '';
      return raw.toString().trim();
    }

    final legacyScopeSourceUrls =
        parseStringList(json['searchScopeSourceUrls']);
    var parsedSearchScope = parseString(json['searchScope']);
    if (parsedSearchScope.isEmpty && legacyScopeSourceUrls.length == 1) {
      parsedSearchScope = '::${legacyScopeSourceUrls.first}';
    }

    return AppSettings(
      appearanceMode: parseAppearanceMode(json['appearanceMode']),
      wifiOnlyDownload: json['wifiOnlyDownload'] as bool? ?? true,
      autoUpdateSources: json['autoUpdateSources'] as bool? ?? true,
      bookshelfViewMode: parseViewMode(json['bookshelfViewMode']),
      bookshelfSortMode: parseSortMode(json['bookshelfSortMode']),
      searchFilterMode: normalizeSearchFilterMode(
          parseSearchFilterMode(json['searchFilterMode'])),
      searchConcurrency:
          parseIntWithDefault(json['searchConcurrency'], 8).clamp(2, 12),
      searchCacheRetentionDays:
          parseIntWithDefault(json['searchCacheRetentionDays'], 5).clamp(1, 30),
      searchScope: parsedSearchScope,
      searchScopeSourceUrls: legacyScopeSourceUrls,
      searchShowCover: json['searchShowCover'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appearanceMode': appearanceMode.index,
      'wifiOnlyDownload': wifiOnlyDownload,
      'autoUpdateSources': autoUpdateSources,
      'bookshelfViewMode': bookshelfViewMode.index,
      'bookshelfSortMode': bookshelfSortMode.index,
      'searchFilterMode': normalizeSearchFilterMode(searchFilterMode).index,
      'searchConcurrency': searchConcurrency,
      'searchCacheRetentionDays': searchCacheRetentionDays,
      'searchScope': searchScope,
      'searchScopeSourceUrls': searchScopeSourceUrls,
      'searchShowCover': searchShowCover,
    };
  }

  AppSettings copyWith({
    AppAppearanceMode? appearanceMode,
    bool? wifiOnlyDownload,
    bool? autoUpdateSources,
    BookshelfViewMode? bookshelfViewMode,
    BookshelfSortMode? bookshelfSortMode,
    SearchFilterMode? searchFilterMode,
    int? searchConcurrency,
    int? searchCacheRetentionDays,
    String? searchScope,
    List<String>? searchScopeSourceUrls,
    bool? searchShowCover,
  }) {
    return AppSettings(
      appearanceMode: appearanceMode ?? this.appearanceMode,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      autoUpdateSources: autoUpdateSources ?? this.autoUpdateSources,
      bookshelfViewMode: bookshelfViewMode ?? this.bookshelfViewMode,
      bookshelfSortMode: bookshelfSortMode ?? this.bookshelfSortMode,
      searchFilterMode: searchFilterMode ?? this.searchFilterMode,
      searchConcurrency: searchConcurrency ?? this.searchConcurrency,
      searchCacheRetentionDays:
          searchCacheRetentionDays ?? this.searchCacheRetentionDays,
      searchScope: searchScope ?? this.searchScope,
      searchScopeSourceUrls:
          searchScopeSourceUrls ?? this.searchScopeSourceUrls,
      searchShowCover: searchShowCover ?? this.searchShowCover,
    );
  }
}
