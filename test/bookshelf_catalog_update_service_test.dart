import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/bookshelf/services/bookshelf_catalog_update_service.dart';

Book _book(
  String id, {
  bool isLocal = false,
}) {
  return Book(
    id: id,
    title: 'Book-$id',
    author: 'Author-$id',
    isLocal: isLocal,
  );
}

void main() {
  group('BookshelfCatalogUpdateService', () {
    test('仅更新网络书籍并按书籍粒度回调更新中状态', () async {
      final books = <Book>[
        _book('remote-1'),
        _book('local-1', isLocal: true),
        _book('remote-2'),
      ];

      final service = BookshelfCatalogUpdateService.forTest(
        singleBookUpdater: (book) async {
          if (book.id == 'remote-1') {
            return BookshelfCatalogUpdateItemResult.success();
          }
          return BookshelfCatalogUpdateItemResult.failed('mock-failed');
        },
      );

      final callbacks = <String>[];
      final summary = await service.updateBooks(
        books,
        onBookUpdatingChanged: (bookId, updating) {
          callbacks.add('$bookId:$updating');
        },
      );

      expect(summary.totalRequestedCount, 3);
      expect(summary.updateCandidateCount, 2);
      expect(summary.successCount, 1);
      expect(summary.skippedCount, 0);
      expect(summary.failedCount, 1);
      expect(summary.failedDetails, hasLength(1));
      expect(summary.failedDetails.first, contains('Book-remote-2'));
      expect(
        callbacks,
        <String>[
          'remote-1:true',
          'remote-1:false',
          'remote-2:true',
          'remote-2:false',
        ],
      );
    });

    test('支持 skipped 结果汇总', () async {
      final books = <Book>[_book('remote-1')];
      final service = BookshelfCatalogUpdateService.forTest(
        singleBookUpdater: (_) async =>
            BookshelfCatalogUpdateItemResult.skipped('skip'),
      );

      final summary = await service.updateBooks(books);
      expect(summary.totalRequestedCount, 1);
      expect(summary.updateCandidateCount, 1);
      expect(summary.successCount, 0);
      expect(summary.skippedCount, 1);
      expect(summary.failedCount, 0);
      expect(summary.failedDetails, isEmpty);
    });

    test('单本更新抛异常时归并为 failed', () async {
      final books = <Book>[_book('remote-1')];
      final service = BookshelfCatalogUpdateService.forTest(
        singleBookUpdater: (_) async {
          throw StateError('boom');
        },
      );

      final summary = await service.updateBooks(books);
      expect(summary.totalRequestedCount, 1);
      expect(summary.updateCandidateCount, 1);
      expect(summary.successCount, 0);
      expect(summary.skippedCount, 0);
      expect(summary.failedCount, 1);
      expect(summary.failedDetails, hasLength(1));
      expect(summary.failedDetails.first, contains('更新异常'));
    });
  });
}
