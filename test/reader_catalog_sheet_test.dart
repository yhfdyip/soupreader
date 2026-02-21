import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/core/database/entities/bookmark_entity.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/reader/widgets/reader_catalog_sheet.dart';

void main() {
  List<Chapter> buildChapters() {
    return const <Chapter>[
      Chapter(
        id: 'c0',
        bookId: 'b1',
        title: '原始章节-零',
        index: 0,
      ),
      Chapter(
        id: 'c1',
        bookId: 'b1',
        title: '原始章节-一',
        index: 1,
      ),
    ];
  }

  Future<void> pumpCatalogSheet(
    WidgetTester tester, {
    required List<Chapter> chapters,
    Map<int, String> initialDisplayTitlesByIndex = const <int, String>{},
    Future<String> Function(Chapter chapter)? resolveDisplayTitle,
    bool isLocalTxtBook = false,
    ValueChanged<bool>? onSplitLongChapterChanged,
    Future<void> Function(bool splitLongChapter)? onApplySplitLongChapter,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderCatalogSheet(
          bookId: 'b1',
          bookTitle: '测试书',
          bookAuthor: '测试作者',
          coverUrl: null,
          chapters: chapters,
          currentChapterIndex: 0,
          bookmarks: const <BookmarkEntity>[],
          onClearBookCache: () async =>
              const ChapterCacheInfo(bytes: 0, chapters: 0),
          onRefreshCatalog: () async => chapters,
          onChapterSelected: (_) {},
          onBookmarkSelected: (_) {},
          onDeleteBookmark: (_) async {},
          initialDisplayTitlesByIndex: initialDisplayTitlesByIndex,
          resolveDisplayTitle: resolveDisplayTitle,
          isLocalTxtBook: isLocalTxtBook,
          onSplitLongChapterChanged: onSplitLongChapterChanged,
          onApplySplitLongChapter: onApplySplitLongChapter,
        ),
      ),
    );
  }

  testWidgets('ReaderCatalogSheet 优先显示初始目录标题映射', (tester) async {
    final chapters = buildChapters();
    await pumpCatalogSheet(
      tester,
      chapters: chapters,
      initialDisplayTitlesByIndex: const <int, String>{
        0: '显示章节-零',
      },
    );
    await tester.pump();

    expect(find.text('显示章节-零'), findsOneWidget);
    expect(find.text('原始章节-零'), findsNothing);
    expect(find.text('原始章节-一'), findsOneWidget);
  });

  testWidgets('ReaderCatalogSheet 目录面板收敛为目录和书签双栏', (tester) async {
    final chapters = buildChapters();
    await pumpCatalogSheet(tester, chapters: chapters);
    await tester.pump();

    expect(find.text('目录 (2)'), findsOneWidget);
    expect(find.text('书签 (0)'), findsOneWidget);
    expect(find.text('笔记'), findsNothing);
  });

  testWidgets('ReaderCatalogSheet 异步目录标题解析失败时回退原始标题', (tester) async {
    final chapters = buildChapters();
    await pumpCatalogSheet(
      tester,
      chapters: chapters,
      resolveDisplayTitle: (chapter) async {
        if (chapter.index == 0) {
          throw StateError('模拟解析失败');
        }
        return '显示章节-${chapter.index}';
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('原始章节-零'), findsOneWidget);
    expect(find.text('显示章节-1'), findsOneWidget);
    expect(find.text('原始章节-一'), findsNothing);
  });

  testWidgets('ReaderCatalogSheet 分割长章节动作按 legado 状态流转', (tester) async {
    final chapters = buildChapters();
    bool? applied;
    bool? changed;
    await pumpCatalogSheet(
      tester,
      chapters: chapters,
      isLocalTxtBook: true,
      onApplySplitLongChapter: (next) async {
        applied = next;
      },
      onSplitLongChapterChanged: (next) {
        changed = next;
      },
    );
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分割长章节'));
    await tester.pumpAndSettle();

    expect(applied, isTrue);
    expect(changed, isTrue);
  });
}
