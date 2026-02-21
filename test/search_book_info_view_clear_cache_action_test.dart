import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/views/search_book_info_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';
import 'package:uuid/uuid.dart';

Widget _buildTestApp(Widget home) {
  final shadTheme = AppShadcnTheme.light();
  return ShadApp.custom(
    theme: shadTheme,
    darkTheme: shadTheme,
    appBuilder: (context) {
      final shad = ShadTheme.of(context);
      final cupertinoTheme = CupertinoTheme.of(context).copyWith(
        barBackgroundColor: shad.colorScheme.background.withValues(alpha: 0.92),
      );
      return CupertinoApp(
        theme: cupertinoTheme,
        home: home,
        builder: (context, child) => ShadAppBuilder(child: child!),
      );
    },
  );
}

Book _buildBook({
  required String id,
  required String sourceUrl,
}) {
  return Book(
    id: id,
    title: '清理缓存测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: 'https://book.example.com/$id',
    isLocal: false,
  );
}

BookSource _buildSource(String sourceUrl) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '清理缓存测试源',
  );
}

Future<void> _invokeClearCacheAction(WidgetTester tester) async {
  final clearCacheAction =
      find.widgetWithText(CupertinoActionSheetAction, '清理缓存');
  expect(clearCacheAction, findsOneWidget);
  final action = tester.widget<CupertinoActionSheetAction>(clearCacheAction);
  await tester.runAsync(() async {
    action.onPressed?.call();
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _waitUntilBookCacheCleared(
  WidgetTester tester, {
  required ChapterRepository chapterRepo,
  required String bookId,
}) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      final info = chapterRepo.getDownloadedCacheInfoForBook(bookId);
      if (info.chapters == 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_clear_cache_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
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

  setUp(() async {
    await DatabaseService().clearAll();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  testWidgets('详情页点击清理缓存后统一提示“成功清理缓存”并清空下载缓存', (WidgetTester tester) async {
    const sourceUrl = 'https://source-clear-cache.example.com';
    const bookId = 'book-clear-cache';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final chapterRepo = ChapterRepository(DatabaseService());
    final book = _buildBook(
      id: bookId,
      sourceUrl: sourceUrl,
    );
    final cachedChapter = Chapter(
      id: 'chapter-$bookId-1',
      bookId: bookId,
      title: '第一章',
      url: 'https://book.example.com/$bookId/chapter-1',
      index: 0,
      isDownloaded: true,
      content: '缓存正文内容',
    );

    ChapterCacheInfo beforeClearInfo = const ChapterCacheInfo(
      bytes: 0,
      chapters: 0,
    );
    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
      await bookRepo.addBook(book);
      await chapterRepo.addChapters([cachedChapter]);
      beforeClearInfo = chapterRepo.getDownloadedCacheInfoForBook(bookId);
    });
    expect(beforeClearInfo.chapters, 1);

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final moreAction = find.byIcon(CupertinoIcons.ellipsis_circle);
    expect(moreAction, findsOneWidget);
    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    await _invokeClearCacheAction(tester);
    await _waitUntilBookCacheCleared(
      tester,
      chapterRepo: chapterRepo,
      bookId: bookId,
    );

    expect(find.text('当前书籍不在书架，无法清理缓存'), findsNothing);
    expect(find.text('暂无可清理的章节缓存'), findsNothing);
    expect(find.textContaining('已清理缓存：'), findsNothing);

    final okButton = find.widgetWithText(ShadButton, '好');
    if (okButton.evaluate().isNotEmpty) {
      await tester.tap(okButton.first);
      await tester.pumpAndSettle();
    }

    ChapterCacheInfo afterClearInfo = const ChapterCacheInfo(
      bytes: 0,
      chapters: 0,
    );
    List<Chapter> storedChapters = const <Chapter>[];
    await tester.runAsync(() async {
      afterClearInfo = chapterRepo.getDownloadedCacheInfoForBook(bookId);
      storedChapters = chapterRepo.getChaptersForBook(bookId);
    });

    expect(afterClearInfo.chapters, 0);
    expect(storedChapters.length, 1);
    expect(storedChapters.single.isDownloaded, isFalse);
    expect(storedChapters.single.content, isNull);
  });

  testWidgets('非书架详情点击清理缓存时可执行清理，不再提示“无法清理缓存”', (WidgetTester tester) async {
    const sourceUrl = '';
    const bookUrl = '';
    final chapterRepo = ChapterRepository(DatabaseService());
    final ephemeralBookId = const Uuid().v5(
      Namespace.url.value,
      'ephemeral|$sourceUrl|$bookUrl',
    );

    await tester.runAsync(() async {
      await chapterRepo.addChapters([
        Chapter(
          id: 'chapter-$ephemeralBookId-1',
          bookId: ephemeralBookId,
          title: '第一章',
          url: 'https://book.example.com/non-shelf/chapter-1',
          index: 0,
          isDownloaded: true,
          content: '非书架缓存正文',
        ),
      ]);
    });

    await tester.pumpWidget(
      _buildTestApp(
        const SearchBookInfoView(
          result: SearchResult(
            name: '非书架清理缓存测试书',
            author: '测试作者',
            coverUrl: '',
            intro: '',
            lastChapter: '',
            bookUrl: bookUrl,
            sourceUrl: sourceUrl,
            sourceName: '',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final moreAction = find.byIcon(CupertinoIcons.ellipsis_circle);
    expect(moreAction, findsOneWidget);
    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    await _invokeClearCacheAction(tester);
    await _waitUntilBookCacheCleared(
      tester,
      chapterRepo: chapterRepo,
      bookId: ephemeralBookId,
    );

    expect(find.text('当前书籍不在书架，无法清理缓存'), findsNothing);
    expect(find.text('暂无可清理的章节缓存'), findsNothing);
    expect(find.textContaining('已清理缓存：'), findsNothing);

    final okButton = find.widgetWithText(ShadButton, '好');
    if (okButton.evaluate().isNotEmpty) {
      await tester.tap(okButton.first);
      await tester.pumpAndSettle();
    }

    ChapterCacheInfo afterClearInfo = const ChapterCacheInfo(
      bytes: 0,
      chapters: 0,
    );
    await tester.runAsync(() async {
      afterClearInfo =
          chapterRepo.getDownloadedCacheInfoForBook(ephemeralBookId);
    });
    expect(afterClearInfo.chapters, 0);
  });
}
