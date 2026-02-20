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

enum MainDefaultHomePage {
  bookshelf,
  explore,
  rss,
  my,
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
  static const String defaultWebDavUrl = 'https://dav.jianguoyun.com/dav/';

  final AppAppearanceMode appearanceMode;
  final bool wifiOnlyDownload;
  final bool autoUpdateSources;
  final bool showDiscovery;
  final bool showRss;
  final MainDefaultHomePage defaultHomePage;

  final BookshelfViewMode bookshelfViewMode;
  final BookshelfSortMode bookshelfSortMode;
  final SearchFilterMode searchFilterMode;
  final int searchConcurrency;
  final int searchCacheRetentionDays;
  final String searchScope;
  final List<String> searchScopeSourceUrls;
  final bool searchShowCover;
  final bool bookInfoDeleteAlert;
  final String webDavUrl;
  final String webDavAccount;
  final String webDavPassword;
  final String webDavDir;

  const AppSettings({
    this.appearanceMode = AppAppearanceMode.followSystem,
    this.wifiOnlyDownload = true,
    this.autoUpdateSources = true,
    this.showDiscovery = true,
    this.showRss = true,
    this.defaultHomePage = MainDefaultHomePage.bookshelf,
    this.bookshelfViewMode = BookshelfViewMode.grid,
    this.bookshelfSortMode = BookshelfSortMode.recentRead,
    this.searchFilterMode = SearchFilterMode.normal,
    this.searchConcurrency = 8,
    this.searchCacheRetentionDays = 5,
    this.searchScope = '',
    this.searchScopeSourceUrls = const <String>[],
    this.searchShowCover = true,
    this.bookInfoDeleteAlert = true,
    this.webDavUrl = defaultWebDavUrl,
    this.webDavAccount = '',
    this.webDavPassword = '',
    this.webDavDir = '',
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

    MainDefaultHomePage parseDefaultHomePage(dynamic raw) {
      if (raw is String) {
        switch (raw.trim().toLowerCase()) {
          case 'explore':
            return MainDefaultHomePage.explore;
          case 'rss':
            return MainDefaultHomePage.rss;
          case 'my':
            return MainDefaultHomePage.my;
          default:
            return MainDefaultHomePage.bookshelf;
        }
      }
      if (raw is int) {
        return MainDefaultHomePage
            .values[raw.clamp(0, MainDefaultHomePage.values.length - 1)];
      }
      if (raw is num) {
        final index = raw.toInt();
        return MainDefaultHomePage
            .values[index.clamp(0, MainDefaultHomePage.values.length - 1)];
      }
      return MainDefaultHomePage.bookshelf;
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

    bool parseBoolWithDefault(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        switch (raw.trim().toLowerCase()) {
          case '1':
          case 'true':
          case 'yes':
          case 'on':
            return true;
          case '0':
          case 'false':
          case 'no':
          case 'off':
            return false;
        }
      }
      return fallback;
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
      showDiscovery: parseBoolWithDefault(json['showDiscovery'], true),
      showRss: parseBoolWithDefault(
        json['showRss'] ?? json['showRSS'],
        true,
      ),
      defaultHomePage: parseDefaultHomePage(json['defaultHomePage']),
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
      bookInfoDeleteAlert: parseBoolWithDefault(
        json['bookInfoDeleteAlert'],
        true,
      ),
      webDavUrl: parseString(
        json['webDavUrl'] ?? json['webdavUrl'] ?? defaultWebDavUrl,
      ),
      webDavAccount: parseString(
        json['webDavAccount'] ?? json['webdavAccount'],
      ),
      webDavPassword: parseString(
        json['webDavPassword'] ?? json['webdavPassword'],
      ),
      webDavDir: parseString(json['webDavDir'] ?? json['webdavDir']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appearanceMode': appearanceMode.index,
      'wifiOnlyDownload': wifiOnlyDownload,
      'autoUpdateSources': autoUpdateSources,
      'showDiscovery': showDiscovery,
      'showRss': showRss,
      'defaultHomePage': defaultHomePage.name,
      'bookshelfViewMode': bookshelfViewMode.index,
      'bookshelfSortMode': bookshelfSortMode.index,
      'searchFilterMode': normalizeSearchFilterMode(searchFilterMode).index,
      'searchConcurrency': searchConcurrency,
      'searchCacheRetentionDays': searchCacheRetentionDays,
      'searchScope': searchScope,
      'searchScopeSourceUrls': searchScopeSourceUrls,
      'searchShowCover': searchShowCover,
      'bookInfoDeleteAlert': bookInfoDeleteAlert,
      'webDavUrl': webDavUrl,
      'webDavAccount': webDavAccount,
      'webDavPassword': webDavPassword,
      'webDavDir': webDavDir,
    };
  }

  AppSettings copyWith({
    AppAppearanceMode? appearanceMode,
    bool? wifiOnlyDownload,
    bool? autoUpdateSources,
    bool? showDiscovery,
    bool? showRss,
    MainDefaultHomePage? defaultHomePage,
    BookshelfViewMode? bookshelfViewMode,
    BookshelfSortMode? bookshelfSortMode,
    SearchFilterMode? searchFilterMode,
    int? searchConcurrency,
    int? searchCacheRetentionDays,
    String? searchScope,
    List<String>? searchScopeSourceUrls,
    bool? searchShowCover,
    bool? bookInfoDeleteAlert,
    String? webDavUrl,
    String? webDavAccount,
    String? webDavPassword,
    String? webDavDir,
  }) {
    return AppSettings(
      appearanceMode: appearanceMode ?? this.appearanceMode,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      autoUpdateSources: autoUpdateSources ?? this.autoUpdateSources,
      showDiscovery: showDiscovery ?? this.showDiscovery,
      showRss: showRss ?? this.showRss,
      defaultHomePage: defaultHomePage ?? this.defaultHomePage,
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
      bookInfoDeleteAlert: bookInfoDeleteAlert ?? this.bookInfoDeleteAlert,
      webDavUrl: webDavUrl ?? this.webDavUrl,
      webDavAccount: webDavAccount ?? this.webDavAccount,
      webDavPassword: webDavPassword ?? this.webDavPassword,
      webDavDir: webDavDir ?? this.webDavDir,
    );
  }
}
