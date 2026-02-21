import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/services/search_book_info_share_helper.dart';

void main() {
  group('SearchBookInfoShareHelper.buildPayload', () {
    test('输出 legado 同义 bookUrl#bookJson 结构', () {
      final book = Book(
        id: 'book-1',
        title: '测试书名',
        author: '测试作者',
        sourceId: 'https://source.example',
        sourceUrl: 'https://source.example',
        bookUrl: 'https://book.example/1',
        latestChapter: '第1章',
        totalChapters: 10,
      );

      final payload = SearchBookInfoShareHelper.buildPayload(book);
      final splitAt = payload.indexOf('#');
      expect(splitAt, greaterThan(0));
      expect(payload.substring(0, splitAt), 'https://book.example/1');

      final jsonPart = payload.substring(splitAt + 1);
      final decoded = jsonDecode(jsonPart) as Map<String, dynamic>;
      expect(decoded['id'], 'book-1');
      expect(decoded['title'], '测试书名');
      expect(decoded['author'], '测试作者');
      expect(decoded['bookUrl'], 'https://book.example/1');
      expect(decoded['sourceUrl'], 'https://source.example');
      expect(decoded['latestChapter'], '第1章');
      expect(decoded['totalChapters'], 10);
    });

    test('bookUrl 为空时仍保留 # 前缀分隔', () {
      final book = Book(
        id: 'book-2',
        title: '无链接书籍',
        author: '作者',
      );

      final payload = SearchBookInfoShareHelper.buildPayload(book);
      expect(payload.startsWith('#'), isTrue);
      final decoded = jsonDecode(payload.substring(1)) as Map<String, dynamic>;
      expect(decoded['id'], 'book-2');
      expect(decoded['bookUrl'], isNull);
    });
  });
}
