import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/services/search_book_info_refresh_helper.dart';

void main() {
  group('SearchBookInfoRefreshHelper.refreshLocalBook', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'soupreader_refresh_helper_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('TXT 本地书籍可重解析并复用 bookId', () async {
      final txtFile = File('${tempDir.path}/refresh_case.txt');
      await txtFile.writeAsString(
        '第1章 开始\n这是一段足够长的正文内容用于分章测试验证A\n\n'
        '第2章 继续\n这里也是足够长的正文内容用于分章测试验证B',
        flush: true,
      );

      final book = Book(
        id: 'book-refresh-txt',
        title: '刷新测试',
        author: '原作者',
        bookUrl: 'local://book-refresh-txt',
        isLocal: true,
        localPath: txtFile.path,
        currentChapter: 1,
        totalChapters: 1,
      );

      final result = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: book,
      );

      expect(result.book.id, book.id);
      expect(result.book.totalChapters, 2);
      expect(result.book.currentChapter, 1);
      expect(result.book.latestChapter, contains('第2章'));
      expect(result.chapters.length, 2);
      expect(result.chapters.first.bookId, book.id);
      expect(result.chapters.last.title, contains('第2章'));
      expect(result.charset, isNotEmpty);
    });

    test('TXT 重解析可按 splitLongChapter 控制拆分策略', () async {
      final txtFile = File('${tempDir.path}/refresh_split_case.txt');
      final longContent = List<String>.filled(6200, '乙').join();
      await txtFile.writeAsString(longContent, flush: true);

      final book = Book(
        id: 'book-refresh-split',
        title: '刷新拆分测试',
        author: '原作者',
        bookUrl: 'local://book-refresh-split',
        isLocal: true,
        localPath: txtFile.path,
        currentChapter: 0,
        totalChapters: 1,
      );

      final splitDisabled = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: book,
        splitLongChapter: false,
      );
      final splitEnabled = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: book,
        splitLongChapter: true,
      );

      expect(splitDisabled.chapters.length, 1);
      expect(splitDisabled.chapters.first.title, '正文');
      expect(splitEnabled.chapters.length, greaterThan(1));
    });

    test('非本地书籍触发刷新会报错', () async {
      const book = Book(
        id: 'book-remote',
        title: '远程书',
        author: '作者',
        isLocal: false,
      );

      expect(
        () => SearchBookInfoRefreshHelper.refreshLocalBook(book: book),
        throwsA(isA<StateError>()),
      );
    });
  });
}
