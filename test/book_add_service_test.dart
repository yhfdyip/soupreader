import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/bookshelf/services/book_add_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp('soupreader_book_add_');
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall call) async {
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

  BookSource buildSource() {
    return const BookSource(
      bookSourceUrl: 'https://source.example',
      bookSourceName: '测试书源',
      enabled: true,
    );
  }

  SearchResult buildSearchResult(BookSource source) {
    return SearchResult(
      name: '测试小说',
      author: '测试作者',
      coverUrl: '',
      intro: '',
      lastChapter: '第1章',
      bookUrl: 'https://book.example/book/1',
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
    );
  }

  test('BookAddService falls back from detail tocUrl to bookUrl', () async {
    final db = DatabaseService();
    final sourceRepo = SourceRepository(db);
    final bookRepo = BookRepository(db);
    final chapterRepo = ChapterRepository(db);

    final source = buildSource();
    await sourceRepo.addSource(source);

    final fakeEngine = _FakeRuleParserEngine(
      bookInfo: const BookDetail(
        name: '详情名',
        author: '详情作者',
        coverUrl: '',
        intro: '',
        kind: '',
        lastChapter: '详情最新章',
        tocUrl: 'https://book.example/toc/1',
        bookUrl: 'https://book.example/book/1',
      ),
      tocByUrl: <String, List<TocItem>>{
        'https://book.example/toc/1': const <TocItem>[],
        'https://book.example/book/1': const <TocItem>[
          TocItem(index: 9, name: '第一章', url: 'https://book.example/ch/1'),
          TocItem(index: 10, name: '第一章（重复）', url: 'https://book.example/ch/1'),
          TocItem(index: 10, name: ' ', url: 'https://book.example/ch/skip'),
          TocItem(index: 11, name: '第二章', url: 'https://book.example/ch/2'),
        ],
      },
    );

    final service = BookAddService(database: db, engine: fakeEngine);
    final result = await service.addFromSearchResult(buildSearchResult(source));

    expect(result.success, isTrue);
    expect(result.bookId, isNotNull);
    expect(fakeEngine.tocRequestUrls, contains('https://book.example/toc/1'));
    expect(fakeEngine.tocRequestUrls, contains('https://book.example/book/1'));

    final storedBook = bookRepo.getBookById(result.bookId!);
    expect(storedBook, isNotNull);
    expect(storedBook!.totalChapters, 2);

    final chapters = chapterRepo.getChaptersForBook(result.bookId!);
    expect(chapters.length, 2);
    expect(chapters[0].index, 0);
    expect(chapters[1].index, 1);
    expect(chapters[0].title, '第一章');
    expect(chapters[1].title, '第二章');
    expect(chapters.map((chapter) => chapter.url).toSet().length, chapters.length);
  });

  test('BookAddService returns clear error when toc entries are invalid',
      () async {
    final db = DatabaseService();
    final sourceRepo = SourceRepository(db);
    final bookRepo = BookRepository(db);

    final source = buildSource();
    await sourceRepo.addSource(source);

    final fakeEngine = _FakeRuleParserEngine(
      bookInfo: const BookDetail(
        name: '详情名',
        author: '详情作者',
        coverUrl: '',
        intro: '',
        kind: '',
        lastChapter: '详情最新章',
        tocUrl: '',
        bookUrl: 'https://book.example/book/1',
      ),
      tocByUrl: <String, List<TocItem>>{
        'https://book.example/book/1': const <TocItem>[
          TocItem(index: 0, name: ' ', url: 'https://book.example/ch/empty-name'),
          TocItem(index: 1, name: '第一章', url: ' '),
        ],
      },
    );

    final service = BookAddService(database: db, engine: fakeEngine);
    final result = await service.addFromSearchResult(buildSearchResult(source));

    expect(result.success, isFalse);
    expect(result.message, contains('章节名或章节链接为空'));
    expect(bookRepo.getAllBooks(), isEmpty);
  });
}

class _FakeRuleParserEngine extends RuleParserEngine {
  final BookDetail? bookInfo;
  final Map<String, List<TocItem>> tocByUrl;
  final List<String> tocRequestUrls = <String>[];

  _FakeRuleParserEngine({
    required this.bookInfo,
    required this.tocByUrl,
  });

  @override
  Future<BookDetail?> getBookInfo(
    BookSource source,
    String bookUrl, {
    bool clearRuntimeVariables = true,
  }) async {
    return bookInfo;
  }

  @override
  Future<List<TocItem>> getToc(
    BookSource source,
    String tocUrl, {
    bool clearRuntimeVariables = true,
  }) async {
    tocRequestUrls.add(tocUrl);
    return tocByUrl[tocUrl.trim()] ?? const <TocItem>[];
  }

  @override
  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) async {
    return TocDebugResult(
      fetch: FetchDebugResult.empty(),
      requestType: DebugRequestType.toc,
      requestUrlRule: tocUrl,
      listRule: '@css:.chapter',
      listCount: 0,
      toc: const <TocItem>[],
      fieldSample: const <String, String>{},
      error: 'mock toc debug error',
    );
  }
}
