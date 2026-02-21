import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/bookshelf/views/cache_export_placeholder_view.dart';
import 'package:soupreader/features/bookshelf/views/bookshelf_group_manage_placeholder_dialog.dart';
import 'package:soupreader/features/bookshelf/views/bookshelf_manage_placeholder_view.dart';
import 'package:soupreader/features/bookshelf/views/remote_books_placeholder_view.dart';
import 'package:soupreader/features/rss/views/rss_articles_placeholder_view.dart';
import 'package:soupreader/features/rss/views/rss_source_manage_view.dart';
import 'package:soupreader/features/search/views/search_view.dart';
import 'package:soupreader/main.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp('soupreader_test_');
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
    await SettingsService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('App launches correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SoupReaderApp());

    // Verify that main bottom tabs keep legado-equivalent labels.
    expect(find.text('书架'), findsWidgets);
    expect(find.text('发现'), findsWidgets);
    expect(find.text('订阅'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
  });

  testWidgets('Bookshelf search action opens SearchView',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final searchAction = find.byIcon(CupertinoIcons.search).first;
    expect(searchAction, findsOneWidget);

    await tester.tap(searchAction);
    await tester.pumpAndSettle();

    expect(find.byType(SearchView), findsOneWidget);
  });

  testWidgets('Bookshelf update toc action keeps legado feedback',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final updateToc = find.text('更新目录').first;
    expect(updateToc, findsOneWidget);

    await tester.tap(updateToc);
    await tester.pumpAndSettle();

    expect(find.text('当前书架没有可更新的网络书籍'), findsOneWidget);
  });

  testWidgets('Bookshelf add local action keeps legado menu label',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.text('添加本地'), findsOneWidget);
    expect(find.text('本机导入'), findsNothing);
  });

  testWidgets('Bookshelf remote action opens remote books page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final remoteAction = find.text('远程书籍').first;
    expect(remoteAction, findsOneWidget);

    await tester.tap(remoteAction);
    await tester.pumpAndSettle();

    expect(find.byType(RemoteBooksPlaceholderView), findsOneWidget);
    expect(find.textContaining('获取webDav书籍出错'), findsOneWidget);
  });

  testWidgets('Bookshelf add url action keeps legado dialog entry',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.text('添加网址'), findsOneWidget);
    expect(find.text('URL 导入'), findsNothing);

    await tester.tap(find.text('添加网址').first);
    await tester.pumpAndSettle();

    expect(find.text('添加书籍网址'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.text('url'), findsOneWidget);
  });

  testWidgets('Bookshelf manage action opens manage page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final manageAction = find.text('书架管理').first;
    expect(manageAction, findsOneWidget);

    await tester.tap(manageAction);
    await tester.pumpAndSettle();

    expect(find.byType(BookshelfManagePlaceholderView), findsOneWidget);
    expect(find.text('书架管理（迁移中）'), findsOneWidget);
  });

  testWidgets('Bookshelf cache export action opens cache export page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.text('缓存/导出'), findsOneWidget);
    expect(find.text('缓存导出'), findsNothing);

    await tester.tap(find.text('缓存/导出').first);
    await tester.pumpAndSettle();

    expect(find.byType(CacheExportPlaceholderView), findsOneWidget);
    expect(find.text('缓存/导出（迁移中）'), findsOneWidget);
  });

  testWidgets('Bookshelf group manage action opens group manage dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final groupManageAction = find.text('分组管理').first;
    expect(groupManageAction, findsOneWidget);

    await tester.tap(groupManageAction);
    await tester.pumpAndSettle();

    expect(
      find.byType(BookshelfGroupManagePlaceholderDialog),
      findsOneWidget,
    );
    expect(find.text('分组管理（迁移中）'), findsOneWidget);
  });

  testWidgets('Bookshelf layout action opens legado-like config dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final layoutAction = find.text('书架布局').first;
    expect(layoutAction, findsOneWidget);

    await tester.tap(layoutAction);
    await tester.pumpAndSettle();

    expect(find.text('书架布局'), findsOneWidget);
    expect(find.text('分组样式'), findsOneWidget);
    expect(find.text('显示未读数量'), findsOneWidget);
    expect(find.text('显示最新更新时间'), findsOneWidget);
    expect(find.text('显示待更新计数'), findsOneWidget);
    expect(find.text('显示快速滚动条'), findsOneWidget);
    expect(find.text('列表'), findsOneWidget);
    expect(find.text('三列网格'), findsOneWidget);
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);

    await tester.tap(find.text('四列网格').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定').first);
    await tester.pumpAndSettle();

    expect(find.text('分组样式'), findsNothing);
  });

  testWidgets('Bookshelf export action keeps legado menu label',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.text('导出书单'), findsOneWidget);
    expect(find.text('导出书架'), findsNothing);
  });

  testWidgets('Bookshelf import action keeps legado dialog entry',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.text('导入书单'), findsOneWidget);
    expect(find.text('导入书架'), findsNothing);

    await tester.drag(
      find.byType(CupertinoActionSheet).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入书单').first);
    await tester.pumpAndSettle();

    expect(find.text('导入书单'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.text('url/json'), findsOneWidget);
    expect(find.text('选择文件'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('Bookshelf log action opens legado-like log dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final moreAction = find.byIcon(CupertinoIcons.ellipsis).first;
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CupertinoActionSheet).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('日志').first);
    await tester.pumpAndSettle();

    expect(find.text('清空'), findsOneWidget);
    expect(find.text('暂无日志'), findsOneWidget);
    expect(find.text('异常日志'), findsNothing);
  });

  testWidgets('RSS favorite action opens favorites page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final rssTab = find.byIcon(CupertinoIcons.dot_radiowaves_left_right).first;
    expect(rssTab, findsOneWidget);

    await tester.tap(rssTab);
    await tester.pumpAndSettle();

    final favoriteAction = find.byIcon(CupertinoIcons.star).first;
    expect(favoriteAction, findsOneWidget);

    await tester.tap(favoriteAction);
    await tester.pumpAndSettle();

    expect(find.byType(RssFavoritesPlaceholderView), findsOneWidget);
    expect(find.text('收藏'), findsWidgets);
  });

  testWidgets('RSS settings action opens source manage page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final rssTab = find.byIcon(CupertinoIcons.dot_radiowaves_left_right).first;
    expect(rssTab, findsOneWidget);

    await tester.tap(rssTab);
    await tester.pumpAndSettle();

    final settingsAction = find.byIcon(CupertinoIcons.settings).hitTestable();
    expect(settingsAction, findsOneWidget);

    await tester.tap(settingsAction);
    await tester.pumpAndSettle();

    expect(find.byType(RssSourceManageView), findsOneWidget);
    expect(find.text('订阅源管理'), findsWidgets);
  });

  testWidgets('My help action opens legado-like app help dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoupReaderApp());
    await tester.pumpAndSettle();

    final myTab = find.byIcon(CupertinoIcons.person).first;
    expect(myTab, findsOneWidget);

    await tester.tap(myTab);
    await tester.pumpAndSettle();

    final helpAction = find.byIcon(CupertinoIcons.question_circle).first;
    expect(helpAction, findsOneWidget);

    await tester.tap(helpAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('帮助'), findsWidgets);
    expect(
      find.textContaining('新人必读', findRichText: true),
      findsOneWidget,
    );
  });
}
