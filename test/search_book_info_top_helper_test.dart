import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/services/search_book_info_top_helper.dart';

void main() {
  group('SearchBookInfoTopHelper.buildPinnedBook', () {
    test('置顶时同步更新最近阅读时间与添加时间', () {
      final original = Book(
        id: 'book-top-helper',
        title: '置顶测试',
        author: '测试作者',
        sourceId: 'https://source.example.com',
        sourceUrl: 'https://source.example.com',
        bookUrl: 'https://book.example.com/top',
        currentChapter: 12,
        totalChapters: 100,
        readProgress: 0.5,
        lastReadTime: DateTime(2023, 1, 1, 10, 0, 0),
        addedTime: DateTime(2023, 1, 2, 10, 0, 0),
      );
      final now = DateTime(2026, 2, 21, 12, 0, 0);

      final pinned = SearchBookInfoTopHelper.buildPinnedBook(
        book: original,
        now: now,
      );

      expect(pinned.id, original.id);
      expect(pinned.title, original.title);
      expect(pinned.author, original.author);
      expect(pinned.currentChapter, original.currentChapter);
      expect(pinned.totalChapters, original.totalChapters);
      expect(pinned.readProgress, original.readProgress);
      expect(pinned.lastReadTime, now);
      expect(pinned.addedTime, now);
    });
  });
}
