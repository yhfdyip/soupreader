import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/bookshelf/services/book_add_service.dart';
import 'package:soupreader/features/bookshelf/services/bookshelf_booklist_import_service.dart';
import 'package:soupreader/features/bookshelf/services/bookshelf_import_export_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_booklist_import_',
    );
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

  BookSource buildSource({
    required String url,
    required String name,
    required int weight,
  }) {
    return BookSource(
      bookSourceUrl: url,
      bookSourceName: name,
      enabled: true,
      weight: weight,
    );
  }

  test('booklist import keeps running when a source throws', () async {
    final db = DatabaseService();
    final sourceRepo = SourceRepository(db);

    final sourceA = buildSource(
      url: 'https://source-a.example',
      name: '高权重异常源',
      weight: 100,
    );
    final sourceB = buildSource(
      url: 'https://source-b.example',
      name: '低权重可用源',
      weight: 10,
    );

    await sourceRepo.addSource(sourceA);
    await sourceRepo.addSource(sourceB);

    final fakeEngine = _FakeBooklistRuleParserEngine(
      searchBySource: <String, Object>{
        sourceA.bookSourceUrl: Exception('HTTP 403 blocked'),
        sourceB.bookSourceUrl: <SearchResult>[
          SearchResult(
            name: '目标书',
            author: '目标作者',
            coverUrl: '',
            intro: '',
            lastChapter: '',
            bookUrl: 'https://book.example/1',
            sourceUrl: sourceB.bookSourceUrl,
            sourceName: sourceB.bookSourceName,
          ),
        ],
      },
    );
    final fakeAddService = _FakeBookAddService();

    final service = BookshelfBooklistImportService(
      database: db,
      engine: fakeEngine,
      addService: fakeAddService,
    );

    final summary = await service.importBySearching(
      const <BooklistItem>[
        BooklistItem(name: '目标书', author: '目标作者'),
      ],
    );

    expect(summary.total, 1);
    expect(summary.added, 1);
    expect(summary.failed, 0);
    expect(summary.errors, isEmpty);
    expect(fakeAddService.addCallCount, 1);
    expect(
      fakeEngine.requestedSourceUrls,
      <String>[sourceA.bookSourceUrl, sourceB.bookSourceUrl],
    );
  });

  test('booklist import includes source error hints when all fail', () async {
    final db = DatabaseService();
    final sourceRepo = SourceRepository(db);

    final sourceA = buildSource(
      url: 'https://source-a.example',
      name: '异常源A',
      weight: 100,
    );
    final sourceB = buildSource(
      url: 'https://source-b.example',
      name: '异常源B',
      weight: 80,
    );

    await sourceRepo.addSource(sourceA);
    await sourceRepo.addSource(sourceB);

    final fakeEngine = _FakeBooklistRuleParserEngine(
      searchBySource: <String, Object>{
        sourceA.bookSourceUrl: Exception('timeout while connecting'),
        sourceB.bookSourceUrl: Exception('invalid html selector'),
      },
    );
    final fakeAddService = _FakeBookAddService();

    final service = BookshelfBooklistImportService(
      database: db,
      engine: fakeEngine,
      addService: fakeAddService,
    );

    final summary = await service.importBySearching(
      const <BooklistItem>[
        BooklistItem(name: '不存在书籍', author: '作者X'),
      ],
    );

    expect(summary.total, 1);
    expect(summary.added, 0);
    expect(summary.failed, 1);
    expect(summary.errors, hasLength(1));
    expect(summary.errors.first, contains('未找到：不存在书籍 - 作者X'));
    expect(summary.errors.first, contains('部分书源异常'));
    expect(summary.errors.first, contains('异常源A'));
    expect(summary.errors.first, contains('异常源B'));
    expect(fakeAddService.addCallCount, 0);
  });
}

class _FakeBooklistRuleParserEngine extends RuleParserEngine {
  final Map<String, Object> searchBySource;
  final List<String> requestedSourceUrls = <String>[];

  _FakeBooklistRuleParserEngine({
    required this.searchBySource,
  });

  @override
  Future<List<SearchResult>> search(BookSource source, String keyword) async {
    requestedSourceUrls.add(source.bookSourceUrl);
    final action = searchBySource[source.bookSourceUrl];
    if (action is Exception) {
      throw action;
    }
    if (action is Error) {
      throw action;
    }
    if (action is List<SearchResult>) {
      return action;
    }
    return const <SearchResult>[];
  }
}

class _FakeBookAddService extends BookAddService {
  int addCallCount = 0;

  _FakeBookAddService() : super(database: DatabaseService());

  @override
  Future<BookAddResult> addFromSearchResult(SearchResult result) async {
    addCallCount++;
    return BookAddResult.success('fake-book-id-$addCallCount');
  }
}
