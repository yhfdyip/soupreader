import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';

void main() {
  test('AppSettings JSON roundtrip', () {
    const settings = AppSettings(
      appearanceMode: AppAppearanceMode.dark,
      wifiOnlyDownload: false,
      autoUpdateSources: false,
      showDiscovery: false,
      showRss: true,
      defaultHomePage: MainDefaultHomePage.rss,
      bookshelfViewMode: BookshelfViewMode.list,
      bookshelfSortMode: BookshelfSortMode.title,
      searchScope: '玄幻,男频',
      bookInfoDeleteAlert: false,
      webDavUrl: 'https://dav.example.com/root/',
      webDavAccount: 'reader',
      webDavPassword: 'secret',
      webDavDir: 'sync',
    );

    final decoded = AppSettings.fromJson(settings.toJson());
    expect(decoded.appearanceMode, AppAppearanceMode.dark);
    expect(decoded.wifiOnlyDownload, false);
    expect(decoded.autoUpdateSources, false);
    expect(decoded.showDiscovery, false);
    expect(decoded.showRss, true);
    expect(decoded.defaultHomePage, MainDefaultHomePage.rss);
    expect(decoded.bookshelfViewMode, BookshelfViewMode.list);
    expect(decoded.bookshelfSortMode, BookshelfSortMode.title);
    expect(decoded.searchScope, '玄幻,男频');
    expect(decoded.bookInfoDeleteAlert, false);
    expect(decoded.webDavUrl, 'https://dav.example.com/root/');
    expect(decoded.webDavAccount, 'reader');
    expect(decoded.webDavPassword, 'secret');
    expect(decoded.webDavDir, 'sync');
  });

  test('AppSettings migrates main tab settings with legacy keys', () {
    final fromLegacy = AppSettings.fromJson({
      'showDiscovery': 0,
      'showRSS': false,
      'defaultHomePage': 'my',
      'bookInfoDeleteAlert': 0,
    });
    expect(fromLegacy.showDiscovery, false);
    expect(fromLegacy.showRss, false);
    expect(fromLegacy.defaultHomePage, MainDefaultHomePage.my);
    expect(fromLegacy.bookInfoDeleteAlert, false);

    final fallback = AppSettings.fromJson({
      'showRss': '1',
      'defaultHomePage': 'unsupported_home',
    });
    expect(fallback.showRss, true);
    expect(fallback.defaultHomePage, MainDefaultHomePage.bookshelf);
    expect(fallback.bookInfoDeleteAlert, true);
    expect(fallback.webDavUrl, AppSettings.defaultWebDavUrl);
    expect(fallback.webDavAccount, isEmpty);
    expect(fallback.webDavPassword, isEmpty);
    expect(fallback.webDavDir, isEmpty);
  });

  test('AppSettings migrates legacy single source scope urls', () {
    final decoded = AppSettings.fromJson({
      'searchScopeSourceUrls': ['https://example.com/source'],
    });
    expect(decoded.searchScope, '::https://example.com/source');
  });

  test('AppSettings migrates legacy search filter mode to precision toggle',
      () {
    final legacyNone = AppSettings.fromJson({
      'searchFilterMode': SearchFilterMode.none.index,
    });
    final legacyNormal = AppSettings.fromJson({
      'searchFilterMode': SearchFilterMode.normal.index,
    });
    final legacyPrecise = AppSettings.fromJson({
      'searchFilterMode': SearchFilterMode.precise.index,
    });

    expect(legacyNone.searchFilterMode, SearchFilterMode.normal);
    expect(legacyNormal.searchFilterMode, SearchFilterMode.normal);
    expect(legacyPrecise.searchFilterMode, SearchFilterMode.precise);

    const normalized = AppSettings(searchFilterMode: SearchFilterMode.none);
    expect(
      normalized.toJson()['searchFilterMode'],
      SearchFilterMode.normal.index,
    );
  });

  test('SettingsService persists app settings', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();
    await service.init();

    expect(service.appSettings.appearanceMode, AppAppearanceMode.followSystem);

    await service.saveAppSettings(
      service.appSettings.copyWith(
        appearanceMode: AppAppearanceMode.light,
        wifiOnlyDownload: false,
        bookInfoDeleteAlert: false,
      ),
    );

    // 重新 init，模拟冷启动读取
    await service.init();
    expect(service.appSettings.appearanceMode, AppAppearanceMode.light);
    expect(service.appSettings.wifiOnlyDownload, false);
    expect(service.appSettings.bookInfoDeleteAlert, false);
  });

  test('SettingsService stores scroll offsets by chapter with fallback',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();
    await service.init();

    expect(service.getScrollOffset('book-1', chapterIndex: 0), 0.0);

    await service.saveScrollOffset('book-1', 123.0, chapterIndex: 0);
    await service.saveScrollOffset('book-1', 456.0, chapterIndex: 1);

    expect(service.getScrollOffset('book-1', chapterIndex: 0), 123.0);
    expect(service.getScrollOffset('book-1', chapterIndex: 1), 456.0);

    // 未写入章节时回退到书籍级偏移（兼容旧键）
    expect(service.getScrollOffset('book-1', chapterIndex: 2), 456.0);
    expect(service.getScrollOffset('book-1'), 456.0);
  });

  test('SettingsService stores chapter page progress and clamps values',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();
    await service.init();

    expect(service.getChapterPageProgress('book-2', chapterIndex: 0), 0.0);

    await service.saveChapterPageProgress(
      'book-2',
      chapterIndex: 0,
      progress: 1.8,
    );
    await service.saveChapterPageProgress(
      'book-2',
      chapterIndex: 1,
      progress: -0.3,
    );

    expect(service.getChapterPageProgress('book-2', chapterIndex: 0), 1.0);
    expect(service.getChapterPageProgress('book-2', chapterIndex: 1), 0.0);
  });

  test('SettingsService persists remote upload url by book id', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();
    await service.init();

    expect(service.getBookRemoteUploadUrl('book-1'), isNull);
    await service.saveBookRemoteUploadUrl(
      'book-1',
      'https://dav.example.com/books/demo.txt',
    );
    expect(
      service.getBookRemoteUploadUrl('book-1'),
      'https://dav.example.com/books/demo.txt',
    );

    await service.init();
    expect(
      service.getBookRemoteUploadUrl('book-1'),
      'https://dav.example.com/books/demo.txt',
    );
  });

  test(
      'SettingsService readingSettingsListenable syncs keepScreenOn/chinese mode',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();
    await service.init();

    final observedModes = <int>[];
    void listener() {
      observedModes
          .add(service.readingSettingsListenable.value.chineseConverterType);
    }

    service.readingSettingsListenable.addListener(listener);
    await service.saveReadingSettings(
      service.readingSettings.copyWith(
        keepScreenOn: true,
        chineseConverterType: ChineseConverterType.traditionalToSimplified,
      ),
    );

    expect(service.readingSettings.keepScreenOn, isTrue);
    expect(
      service.readingSettings.keepLightSeconds,
      ReadingSettings.keepLightAlways,
    );
    expect(
      service.readingSettings.chineseConverterType,
      ChineseConverterType.traditionalToSimplified,
    );
    expect(service.readingSettingsListenable.value.keepScreenOn, isTrue);
    expect(
      service.readingSettingsListenable.value.keepLightSeconds,
      ReadingSettings.keepLightAlways,
    );
    expect(
      service.readingSettingsListenable.value.chineseConverterType,
      ChineseConverterType.traditionalToSimplified,
    );
    expect(observedModes, isNotEmpty);
    expect(observedModes.last, ChineseConverterType.traditionalToSimplified);

    await service.init();
    expect(service.readingSettings.keepScreenOn, isTrue);
    expect(
      service.readingSettings.keepLightSeconds,
      ReadingSettings.keepLightAlways,
    );
    expect(
      service.readingSettings.chineseConverterType,
      ChineseConverterType.traditionalToSimplified,
    );

    service.readingSettingsListenable.removeListener(listener);
  });

  test('SettingsService keeps reading settings during schema migration',
      () async {
    final legacyReadingSettings = const ReadingSettings(
      fontSize: 31.0,
      keepScreenOn: true,
      pageTurnMode: PageTurnMode.scroll,
      pageDirection: PageDirection.horizontal,
      showHeaderLine: true,
    ).toJson();

    SharedPreferences.setMockInitialValues(<String, Object>{
      'reading_settings': json.encode(legacyReadingSettings),
      'reading_settings_schema_version': 0,
    });

    final service = SettingsService();
    await service.init();

    expect(service.readingSettings.fontSize, 31.0);
    expect(service.readingSettings.keepScreenOn, isTrue);
    expect(
      service.readingSettings.keepLightSeconds,
      ReadingSettings.keepLightAlways,
    );
    expect(service.readingSettings.pageTurnMode, PageTurnMode.scroll);
    expect(service.readingSettings.pageDirection, PageDirection.vertical);
    expect(service.readingSettings.showHeaderLine, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final repairedJson = prefs.getString('reading_settings');
    expect(repairedJson, isNotNull);
    final persisted = ReadingSettings.fromJson(
      json.decode(repairedJson!) as Map<String, dynamic>,
    );
    expect(persisted.fontSize, 31.0);
    expect(persisted.pageDirection, PageDirection.vertical);
    expect(prefs.getInt('reading_settings_schema_version'), 3);
  });

  test('SettingsService repairs malformed reading settings json', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'reading_settings': '{"fontSize":',
      'reading_settings_schema_version': 2,
    });

    final service = SettingsService();
    await service.init();

    expect(service.readingSettings.fontSize, const ReadingSettings().fontSize);
    expect(
      service.readingSettings.showHeaderLine,
      const ReadingSettings().showHeaderLine,
    );

    final prefs = await SharedPreferences.getInstance();
    final repairedJson = prefs.getString('reading_settings');
    expect(repairedJson, isNotNull);
    expect(() => json.decode(repairedJson!), returnsNormally);
  });

  test('SettingsService saveReadingSettings normalizes direction and schema',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = SettingsService();
    await service.init();

    await service.saveReadingSettings(
      service.readingSettings.copyWith(
        pageTurnMode: PageTurnMode.scroll,
        pageDirection: PageDirection.horizontal,
      ),
    );

    expect(service.readingSettings.pageTurnMode, PageTurnMode.scroll);
    expect(service.readingSettings.pageDirection, PageDirection.vertical);

    await service.init();
    expect(service.readingSettings.pageTurnMode, PageTurnMode.scroll);
    expect(service.readingSettings.pageDirection, PageDirection.vertical);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('reading_settings_schema_version'), 3);
  });

  test('SettingsService 持久化书籍级允许更新/分割长章节/替换规则开关', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = SettingsService();
    await service.init();

    expect(service.getBookCanUpdate('book-1'), isTrue);
    expect(service.getBookSplitLongChapter('book-1'), isTrue);
    expect(service.getBookUseReplaceRule('book-1'), isTrue);

    await service.saveBookCanUpdate('book-1', false);
    await service.saveBookSplitLongChapter('book-1', false);
    await service.saveBookUseReplaceRule('book-1', false);

    expect(service.getBookCanUpdate('book-1'), isFalse);
    expect(service.getBookSplitLongChapter('book-1'), isFalse);
    expect(service.getBookUseReplaceRule('book-1'), isFalse);

    await service.init();
    expect(service.getBookCanUpdate('book-1'), isFalse);
    expect(service.getBookSplitLongChapter('book-1'), isFalse);
    expect(service.getBookUseReplaceRule('book-1'), isFalse);
    expect(service.getBookCanUpdate(''), isTrue);
    expect(service.getBookSplitLongChapter(''), isTrue);
    expect(service.getBookUseReplaceRule(''), isTrue);
  });

  test('SettingsService 兼容旧格式书籍级开关映射', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'book_can_update_map':
          '{"book-a":0,"book-b":"true","book-c":"0","book-d":1}',
      'book_split_long_chapter_map':
          '{"book-a":"false","book-b":"1","book-c":0,"book-d":true}',
      'book_use_replace_rule_map':
          '{"book-a":0,"book-b":"true","book-c":"0","book-d":1}',
    });
    final service = SettingsService();
    await service.init();

    expect(service.getBookCanUpdate('book-a'), isFalse);
    expect(service.getBookCanUpdate('book-b'), isTrue);
    expect(service.getBookCanUpdate('book-c'), isFalse);
    expect(service.getBookCanUpdate('book-d'), isTrue);

    expect(service.getBookSplitLongChapter('book-a'), isFalse);
    expect(service.getBookSplitLongChapter('book-b'), isTrue);
    expect(service.getBookSplitLongChapter('book-c'), isFalse);
    expect(service.getBookSplitLongChapter('book-d'), isTrue);

    expect(service.getBookUseReplaceRule('book-a'), isFalse);
    expect(service.getBookUseReplaceRule('book-b'), isTrue);
    expect(service.getBookUseReplaceRule('book-c'), isFalse);
    expect(service.getBookUseReplaceRule('book-d'), isTrue);
  });
}
