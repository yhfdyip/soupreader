import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';
import 'package:soupreader/features/rss/services/rss_article_sync_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

class _FakeGateway implements RssArticleRuleGateway {
  _FakeGateway({
    List<SearchDebugResult>? searchResponses,
    List<BookInfoDebugResult>? infoResponses,
    List<ScriptHttpResponse>? fetchResponses,
  })  : _searchResponses = List<SearchDebugResult>.from(
          searchResponses ?? const <SearchDebugResult>[],
        ),
        _infoResponses = List<BookInfoDebugResult>.from(
          infoResponses ?? const <BookInfoDebugResult>[],
        ),
        _fetchResponses = List<ScriptHttpResponse>.from(
          fetchResponses ?? const <ScriptHttpResponse>[],
        );

  final List<SearchDebugResult> _searchResponses;
  final List<BookInfoDebugResult> _infoResponses;
  final List<ScriptHttpResponse> _fetchResponses;

  @override
  Future<SearchDebugResult> searchDebug({
    required BookSource source,
    required String keyword,
    required int page,
  }) async {
    if (_searchResponses.isEmpty) {
      return SearchDebugResult(
        fetch: _fetchOk(body: null),
        requestType: DebugRequestType.search,
        requestUrlRule: source.searchUrl,
        listRule: source.ruleSearch?.bookList,
        listCount: 0,
        results: const <SearchResult>[],
        fieldSample: const <String, String>{},
        error: 'no fake search response',
      );
    }
    return _searchResponses.removeAt(0);
  }

  @override
  Future<BookInfoDebugResult> getBookInfoDebug({
    required BookSource source,
    required String bookUrl,
  }) async {
    if (_infoResponses.isEmpty) {
      return BookInfoDebugResult(
        fetch: _fetchOk(body: null),
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: null,
        initMatched: false,
        detail: null,
        fieldSample: const <String, String>{},
        error: 'no fake bookInfo response',
      );
    }
    return _infoResponses.removeAt(0);
  }

  @override
  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
  }) async {
    if (_fetchResponses.isEmpty) {
      return const ScriptHttpResponse(
        requestUrl: '',
        finalUrl: '',
        statusCode: 500,
        statusMessage: 'ERR',
        headers: <String, String>{},
        body: '',
      );
    }
    return _fetchResponses.removeAt(0);
  }
}

FetchDebugResult _fetchOk({
  required String? body,
}) {
  final snippet =
      body == null ? null : (body.length > 120 ? body.substring(0, 120) : body);
  return FetchDebugResult(
    requestUrl: 'https://rss.example.com/list',
    finalUrl: 'https://rss.example.com/list',
    statusCode: body == null ? null : 200,
    elapsedMs: 1,
    responseLength: body?.length ?? 0,
    responseSnippet: snippet,
    requestHeaders: const <String, String>{},
    headersWarning: null,
    responseHeaders: const <String, String>{},
    error: body == null ? 'error' : null,
    body: body,
  );
}

SearchResult _searchItem({
  required String name,
  required String bookUrl,
  String intro = '',
  String coverUrl = '',
  String updateTime = '',
}) {
  return SearchResult(
    name: name,
    author: '',
    coverUrl: coverUrl,
    intro: intro,
    lastChapter: '',
    updateTime: updateTime,
    bookUrl: bookUrl,
    sourceUrl: 'https://rss.example.com',
    sourceName: '测试源',
  );
}

BookInfoDebugResult _nextPageInfo(String tocUrl) {
  return BookInfoDebugResult(
    fetch: _fetchOk(body: '<html></html>'),
    requestType: DebugRequestType.bookInfo,
    requestUrlRule: 'https://rss.example.com/list',
    initRule: null,
    initMatched: true,
    detail: BookDetail(
      name: '',
      author: '',
      coverUrl: '',
      intro: '',
      kind: '',
      lastChapter: '',
      tocUrl: tocUrl,
      bookUrl: 'https://rss.example.com/list',
    ),
    fieldSample: const <String, String>{},
    error: null,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_rss_sync_service_',
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

  test('规则解析分支：映射文章字段并解析 nextPage URL', () async {
    final gateway = _FakeGateway(
      searchResponses: <SearchDebugResult>[
        SearchDebugResult(
          fetch: _fetchOk(body: '<html>ok</html>'),
          requestType: DebugRequestType.search,
          requestUrlRule: 'https://rss.example.com/list',
          listRule: '.item',
          listCount: 1,
          results: <SearchResult>[
            _searchItem(
              name: '标题-1',
              bookUrl: '/a1',
              intro: '摘要-1',
              updateTime: '2026-02-19',
            ),
          ],
          fieldSample: const <String, String>{},
          error: null,
        ),
      ],
      infoResponses: <BookInfoDebugResult>[
        _nextPageInfo('/page2'),
      ],
    );
    final service = RssArticleFetchService(gateway: gateway);
    final source = const RssSource(
      sourceUrl: 'https://rss.example.com',
      sourceName: '测试源',
      ruleArticles: '.item',
      ruleTitle: '.title@text',
      ruleLink: 'a@href',
      ruleDescription: '.desc@text',
      rulePubDate: '.time@text',
      ruleNextPage: '.next@href',
    );

    final result = await service.fetchPage(
      source: source,
      sortName: '头条',
      sortUrl: 'https://rss.example.com/list',
      page: 1,
    );

    expect(result.error, isNull);
    expect(result.articles.length, 1);
    expect(result.articles.single.title, '标题-1');
    expect(result.articles.single.link, 'https://rss.example.com/a1');
    expect(result.articles.single.pubDate, '2026-02-19');
    expect(result.articles.single.description, '摘要-1');
    expect(result.nextPageUrl, 'https://rss.example.com/page2');
    expect(result.hasMore, isTrue);
  });

  test('默认 XML 分支：ruleArticles 为空时回退默认解析并支持 PAGE', () async {
    const xml = '''
<rss><channel><item>
  <title>默认-1</title>
  <link>https://rss.example.com/a1</link>
</item></channel></rss>
''';
    final gateway = _FakeGateway(
      fetchResponses: const <ScriptHttpResponse>[
        ScriptHttpResponse(
          requestUrl: 'https://rss.example.com/list',
          finalUrl: 'https://rss.example.com/list',
          statusCode: 200,
          statusMessage: 'OK',
          headers: <String, String>{},
          body: xml,
        ),
      ],
    );
    final service = RssArticleFetchService(gateway: gateway);
    final source = const RssSource(
      sourceUrl: 'https://rss.example.com',
      sourceName: '测试源',
      ruleNextPage: 'PAGE',
    );

    final result = await service.fetchPage(
      source: source,
      sortName: '默认分组',
      sortUrl: 'https://rss.example.com/list',
      page: 1,
    );

    expect(result.error, isNull);
    expect(result.articles.map((e) => e.title), <String>['默认-1']);
    expect(result.nextPageUrl, 'https://rss.example.com/list');
    expect(result.hasMore, isTrue);
  });

  test('分页去重：首条和末条都已存在时停止继续加载', () async {
    final gateway = _FakeGateway(
      searchResponses: <SearchDebugResult>[
        // refresh
        SearchDebugResult(
          fetch: _fetchOk(body: '<html>page1</html>'),
          requestType: DebugRequestType.search,
          requestUrlRule: 'https://rss.example.com/list',
          listRule: '.item',
          listCount: 2,
          results: <SearchResult>[
            _searchItem(name: 'A', bookUrl: '/a'),
            _searchItem(name: 'B', bookUrl: '/b'),
          ],
          fieldSample: const <String, String>{},
          error: null,
        ),
        // loadMore（重复首尾）
        SearchDebugResult(
          fetch: _fetchOk(body: '<html>page2</html>'),
          requestType: DebugRequestType.search,
          requestUrlRule: 'https://rss.example.com/list',
          listRule: '.item',
          listCount: 2,
          results: <SearchResult>[
            _searchItem(name: 'A', bookUrl: '/a'),
            _searchItem(name: 'B', bookUrl: '/b'),
          ],
          fieldSample: const <String, String>{},
          error: null,
        ),
      ],
    );

    final syncService = RssArticleSyncService(
      db: DatabaseService(),
      fetchService: RssArticleFetchService(gateway: gateway),
    );
    final source = const RssSource(
      sourceUrl: 'https://rss.example.com',
      sourceName: '测试源',
      ruleArticles: '.item',
      ruleTitle: '.title@text',
      ruleLink: 'a@href',
      ruleNextPage: 'PAGE',
    );

    final refresh = await syncService.refresh(
      source: source,
      sortName: '头条',
      sortUrl: 'https://rss.example.com/list',
    );
    expect(refresh.error, isNull);
    expect(refresh.articles.length, 2);
    expect(refresh.session.hasMore, isTrue);

    final loadMore = await syncService.loadMore(
      source: source,
      session: refresh.session,
    );
    expect(loadMore.appendedArticles, isEmpty);
    expect(loadMore.session.hasMore, isFalse);
    expect(loadMore.session.page, 2);
  });
}
