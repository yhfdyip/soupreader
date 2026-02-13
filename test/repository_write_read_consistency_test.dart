import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/core/database/repositories/bookmark_repository.dart';
import 'package:soupreader/core/database/repositories/replace_rule_repository.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/replace/models/replace_rule.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_repo_write_read_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
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
  });

  test('Book/Chapter 仓储写后立即读一致', () async {
    final db = DatabaseService();
    final bookRepo = BookRepository(db);
    final chapterRepo = ChapterRepository(db);
    const bookId = 'book-write-read';

    await bookRepo.addBook(
      const Book(
        id: bookId,
        title: '测试书',
        author: '测试作者',
      ),
    );
    expect(bookRepo.getBookById(bookId)?.title, '测试书');

    await chapterRepo.addChapters(
      const <Chapter>[
        Chapter(
          id: 'chapter-1',
          bookId: bookId,
          title: '第1章',
          url: 'https://example.org/chapter/1',
          index: 0,
        ),
      ],
    );
    expect(
      chapterRepo.getChaptersForBook(bookId).map((c) => c.id),
      contains('chapter-1'),
    );

    await bookRepo.deleteBook(bookId);
    expect(bookRepo.getBookById(bookId), isNull);
    expect(chapterRepo.getChaptersForBook(bookId), isEmpty);
  });

  test('Bookmark 仓储写后立即读一致', () async {
    final repo = BookmarkRepository();
    await repo.init();

    final bookmark = await repo.addBookmark(
      bookId: 'book-bookmark',
      bookName: '测试书',
      bookAuthor: '测试作者',
      chapterIndex: 3,
      chapterTitle: '第4章',
      chapterPos: 18,
      content: 'test',
    );

    expect(
      repo.getBookmarksForBook('book-bookmark').map((b) => b.id),
      contains(bookmark.id),
    );

    await repo.removeBookmark(bookmark.id);
    expect(
      repo.getBookmarksForBook('book-bookmark').map((b) => b.id),
      isNot(contains(bookmark.id)),
    );
  });

  test('ReplaceRule 仓储写后立即读一致', () async {
    final db = DatabaseService();
    final repo = ReplaceRuleRepository(db);

    const enabledRule = ReplaceRule(
      id: 101,
      name: '启用规则',
      pattern: 'a',
      replacement: 'b',
      isEnabled: true,
      order: 1,
    );
    const disabledRule = ReplaceRule(
      id: 102,
      name: '禁用规则',
      pattern: 'x',
      replacement: 'y',
      isEnabled: false,
      order: 2,
    );

    await repo.addRules(const <ReplaceRule>[enabledRule, disabledRule]);
    expect(repo.getAllRules().map((r) => r.id), containsAll(<int>[101, 102]));
    expect(repo.getEnabledRulesSorted().map((r) => r.id), contains(101));

    await repo.deleteDisabledRules();
    expect(repo.getAllRules().map((r) => r.id), isNot(contains(102)));
  });
}
