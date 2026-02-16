import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/core/services/settings_service.dart';

void main() {
  test('AppSettings JSON roundtrip', () {
    const settings = AppSettings(
      appearanceMode: AppAppearanceMode.dark,
      wifiOnlyDownload: false,
      autoUpdateSources: false,
      bookshelfViewMode: BookshelfViewMode.list,
      bookshelfSortMode: BookshelfSortMode.title,
      searchScope: '玄幻,男频',
    );

    final decoded = AppSettings.fromJson(settings.toJson());
    expect(decoded.appearanceMode, AppAppearanceMode.dark);
    expect(decoded.wifiOnlyDownload, false);
    expect(decoded.autoUpdateSources, false);
    expect(decoded.bookshelfViewMode, BookshelfViewMode.list);
    expect(decoded.bookshelfSortMode, BookshelfSortMode.title);
    expect(decoded.searchScope, '玄幻,男频');
  });

  test('AppSettings migrates legacy single source scope urls', () {
    final decoded = AppSettings.fromJson({
      'searchScopeSourceUrls': ['https://example.com/source'],
    });
    expect(decoded.searchScope, '::https://example.com/source');
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
      ),
    );

    // 重新 init，模拟冷启动读取
    await service.init();
    expect(service.appSettings.appearanceMode, AppAppearanceMode.light);
    expect(service.appSettings.wifiOnlyDownload, false);
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
}
